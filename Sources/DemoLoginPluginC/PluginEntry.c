#include "DemoLoginPlugin.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Security/AuthorizationPlugin.h>
#include <Security/AuthorizationTags.h>
#include <fcntl.h>
#include <os/log.h>
#include <spawn.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static const char *kDemoLoginShellDefaultPath = "/Library/Application Support/DemoSSO/bin/DemoLoginShell.app/Contents/MacOS/DemoLoginShell";
static const char *kDemoLoginPluginResultTemplate = "/tmp/demo-login-plugin-result.XXXXXX";
static const char *kDemoLoginPluginIDPDefaultURL = "http://127.0.0.1:48080/";
static const int kDemoLoginShellTimeoutSecondsDefault = 15;

typedef struct DemoHelperDecision {
    AuthorizationResult result;
    char *username;
    char *password;
    char *message;
} DemoHelperDecision;

typedef struct DemoPluginContext {
    const AuthorizationCallbacks *callbacks;
} DemoPluginContext;

typedef struct DemoMechanismContext {
    DemoPluginContext *plugin;
    AuthorizationEngineRef engine;
} DemoMechanismContext;

static os_log_t DemoPluginLogger(void) {
    static os_log_t logger = NULL;
    if (logger == NULL) {
        logger = os_log_create("com.demo.sso.login-plugin", "authorization");
    }
    return logger;
}

static void DemoHelperDecisionReset(DemoHelperDecision *decision) {
    if (decision == NULL) {
        return;
    }

    free(decision->username);
    free(decision->password);
    free(decision->message);
    decision->username = NULL;
    decision->password = NULL;
    decision->message = NULL;
}

static char *DemoCopyString(const char *value) {
    if (value == NULL) {
        return NULL;
    }

    size_t length = strlen(value);
    char *copy = calloc(length + 1, sizeof(char));
    if (copy == NULL) {
        return NULL;
    }

    memcpy(copy, value, length);
    copy[length] = '\0';
    return copy;
}

static char *DemoCopyEnvironmentValue(const char *name, const char *fallbackValue) {
    const char *value = getenv(name);
    if (value == NULL || value[0] == '\0') {
        value = fallbackValue;
    }
    return DemoCopyString(value);
}

static char *DemoCreateResultPath(void) {
    char *path = DemoCopyString(kDemoLoginPluginResultTemplate);
    if (path == NULL) {
        return NULL;
    }

    int fd = mkstemp(path);
    if (fd < 0) {
        free(path);
        return NULL;
    }

    close(fd);
    return path;
}

static int DemoReadShellTimeoutSeconds(void) {
    const char *value = getenv("DEMO_LOGIN_SHELL_TIMEOUT_SECONDS");
    if (value == NULL || value[0] == '\0') {
        return kDemoLoginShellTimeoutSecondsDefault;
    }

    char *end = NULL;
    long parsed = strtol(value, &end, 10);
    if (end == value || parsed <= 0 || parsed > INT32_MAX) {
        return kDemoLoginShellTimeoutSecondsDefault;
    }

    return (int)parsed;
}

static OSStatus DemoSetStringContextValue(
    DemoMechanismContext *context,
    AuthorizationString key,
    const char *value
) {
    if (context == NULL || key == NULL || value == NULL) {
        return errAuthorizationInternal;
    }

    if (context->plugin == NULL || context->plugin->callbacks == NULL || context->plugin->callbacks->SetContextValue == NULL) {
        return errAuthorizationInternal;
    }

    AuthorizationValue authValue = {
        .length = strlen(value),
        .data = (void *)value,
    };

    return context->plugin->callbacks->SetContextValue(
        context->engine,
        key,
        kAuthorizationContextFlagVolatile,
        &authValue
    );
}

static OSStatus DemoSetStringHintValue(
    DemoMechanismContext *context,
    AuthorizationString key,
    const char *value
) {
    if (context == NULL || key == NULL || value == NULL) {
        return errAuthorizationInternal;
    }

    if (context->plugin == NULL || context->plugin->callbacks == NULL || context->plugin->callbacks->SetHintValue == NULL) {
        return errAuthorizationInternal;
    }

    AuthorizationValue authValue = {
        .length = strlen(value),
        .data = (void *)value,
    };

    return context->plugin->callbacks->SetHintValue(context->engine, key, &authValue);
}

static OSStatus DemoSetSharedHintValue(DemoMechanismContext *context) {
    static const char sharedMarker[] = "";
    if (context == NULL) {
        return errAuthorizationInternal;
    }

    if (context->plugin == NULL || context->plugin->callbacks == NULL || context->plugin->callbacks->SetHintValue == NULL) {
        return errAuthorizationInternal;
    }

    AuthorizationValue authValue = {
        .length = 0,
        .data = (void *)sharedMarker,
    };

    return context->plugin->callbacks->SetHintValue(context->engine, kAuthorizationEnvironmentShared, &authValue);
}

OSStatus DemoPluginApplyCredentials(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    const char *username,
    const char *password
) {
    if (callbacks == NULL || engine == NULL || username == NULL || password == NULL) {
        return errAuthorizationInternal;
    }

    DemoMechanismContext context = {
        .plugin = &(DemoPluginContext){
            .callbacks = callbacks,
        },
        .engine = engine,
    };

    OSStatus status = DemoSetStringContextValue(&context, kAuthorizationEnvironmentUsername, username);
    if (status != errAuthorizationSuccess) {
        return status;
    }

    status = DemoSetStringContextValue(&context, kAuthorizationEnvironmentPassword, password);
    if (status != errAuthorizationSuccess) {
        return status;
    }

    if (callbacks->SetHintValue != NULL) {
        status = DemoSetStringHintValue(&context, kAuthorizationEnvironmentUsername, username);
        if (status != errAuthorizationSuccess) {
            return status;
        }

        status = DemoSetStringHintValue(&context, kAuthorizationEnvironmentPassword, password);
        if (status != errAuthorizationSuccess) {
            return status;
        }

        status = DemoSetSharedHintValue(&context);
        if (status != errAuthorizationSuccess) {
            return status;
        }
    }

    os_log_info(
        DemoPluginLogger(),
        "MechanismInvoke applied credentials username=%{public}s",
        username
    );
    return errAuthorizationSuccess;
}

OSStatus DemoPluginSetAuthorizationResult(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    AuthorizationResult result
) {
    if (callbacks == NULL || callbacks->SetResult == NULL || engine == NULL) {
        return errAuthorizationInternal;
    }

    os_log_info(DemoPluginLogger(), "MechanismInvoke completed result=%u", (unsigned)result);
    return callbacks->SetResult(engine, result);
}

static char *DemoCopyCFString(CFTypeRef value) {
    if (value == NULL || CFGetTypeID(value) != CFStringGetTypeID()) {
        return NULL;
    }

    CFStringRef string = (CFStringRef)value;
    CFIndex maxLength = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8) + 1;
    char *buffer = calloc((size_t)maxLength, sizeof(char));
    if (buffer == NULL) {
        return NULL;
    }

    if (!CFStringGetCString(string, buffer, maxLength, kCFStringEncodingUTF8)) {
        free(buffer);
        return NULL;
    }

    return buffer;
}

static CFDataRef DemoCreateFileData(const char *path) {
    if (path == NULL) {
        return NULL;
    }

    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return NULL;
    }

    struct stat fileStat;
    if (fstat(fd, &fileStat) != 0 || fileStat.st_size < 0) {
        close(fd);
        return NULL;
    }

    size_t length = (size_t)fileStat.st_size;
    UInt8 *buffer = NULL;
    if (length > 0) {
        buffer = calloc(length, sizeof(UInt8));
        if (buffer == NULL) {
            close(fd);
            return NULL;
        }
    }

    size_t offset = 0;
    while (offset < length) {
        ssize_t count = read(fd, buffer + offset, length - offset);
        if (count <= 0) {
            free(buffer);
            close(fd);
            return NULL;
        }
        offset += (size_t)count;
    }
    close(fd);

    CFDataRef data = CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)length);
    free(buffer);
    return data;
}

static OSStatus DemoReadHelperDecision(const char *resultPath, DemoHelperDecision *decision) {
    if (resultPath == NULL || decision == NULL) {
        return errAuthorizationInternal;
    }

    CFDataRef data = DemoCreateFileData(resultPath);
    if (data == NULL) {
        return errAuthorizationInternal;
    }

    CFErrorRef error = NULL;
    CFPropertyListRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListImmutable, NULL, &error);
    CFRelease(data);
    if (plist == NULL || CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
        if (plist != NULL) {
            CFRelease(plist);
        }
        if (error != NULL) {
            CFRelease(error);
        }
        return errAuthorizationInternal;
    }

    CFDictionaryRef dictionary = (CFDictionaryRef)plist;
    char *action = DemoCopyCFString(CFDictionaryGetValue(dictionary, CFSTR("action")));
    if (action == NULL) {
        CFRelease(plist);
        return errAuthorizationInternal;
    }

    if (strcmp(action, "allow") == 0) {
        decision->result = kAuthorizationResultAllow;
    } else if (strcmp(action, "deny") == 0) {
        decision->result = kAuthorizationResultDeny;
    } else if (strcmp(action, "userCanceled") == 0 || strcmp(action, "cancel") == 0) {
        decision->result = kAuthorizationResultUserCanceled;
    } else {
        free(action);
        CFRelease(plist);
        return errAuthorizationInternal;
    }
    free(action);

    decision->username = DemoCopyCFString(CFDictionaryGetValue(dictionary, CFSTR("username")));
    if (decision->username == NULL) {
        decision->username = DemoCopyCFString(CFDictionaryGetValue(dictionary, CFSTR("localShortName")));
    }
    decision->password = DemoCopyCFString(CFDictionaryGetValue(dictionary, CFSTR("password")));
    decision->message = DemoCopyCFString(CFDictionaryGetValue(dictionary, CFSTR("message")));

    CFRelease(plist);
    return errAuthorizationSuccess;
}

static OSStatus DemoRunLoginShell(
    DemoMechanismContext *context,
    const char *shellPath,
    const char *resultPath,
    const char *idpBaseURL,
    DemoHelperDecision *decision
) {
    (void)context;

    if (shellPath == NULL || resultPath == NULL || idpBaseURL == NULL || decision == NULL) {
        return errAuthorizationInternal;
    }

    char *const argv[] = {
        (char *)shellPath,
        "--plugin-result-file",
        (char *)resultPath,
        "--plugin-idp-base-url",
        (char *)idpBaseURL,
        NULL,
    };

    pid_t pid = 0;
    int spawnStatus = posix_spawn(&pid, shellPath, NULL, NULL, argv, environ);
    if (spawnStatus != 0) {
        os_log_error(
            DemoPluginLogger(),
            "MechanismInvoke failed to spawn login shell path=%{public}s error=%d",
            shellPath,
            spawnStatus
        );
        return errAuthorizationInternal;
    }

    os_log_info(
        DemoPluginLogger(),
        "MechanismInvoke spawned login shell pid=%d path=%{public}s resultPath=%{public}s",
        pid,
        shellPath,
        resultPath
    );

    int timeoutSeconds = DemoReadShellTimeoutSeconds();
    time_t startedAt = time(NULL);
    int waitStatus = 0;

    while (1) {
        pid_t waitResult = waitpid(pid, &waitStatus, WNOHANG);
        if (waitResult == pid) {
            break;
        }

        if (waitResult < 0) {
            os_log_error(DemoPluginLogger(), "MechanismInvoke failed waiting for login shell pid=%d", pid);
            return errAuthorizationInternal;
        }

        if ((time(NULL) - startedAt) >= timeoutSeconds) {
            os_log_error(
                DemoPluginLogger(),
                "MechanismInvoke timed out waiting for login shell pid=%d timeout=%d",
                pid,
                timeoutSeconds
            );
            kill(pid, SIGKILL);
            waitpid(pid, &waitStatus, 0);
            return errAuthorizationInternal;
        }

        usleep(100000);
    }

    if (!WIFEXITED(waitStatus) || WEXITSTATUS(waitStatus) != 0) {
        os_log_error(
            DemoPluginLogger(),
            "MechanismInvoke login shell exited abnormally pid=%d status=%d",
            pid,
            waitStatus
        );
        return errAuthorizationInternal;
    }

    return DemoReadHelperDecision(resultPath, decision);
}

static OSStatus DemoPluginDestroy(AuthorizationPluginRef plugin) {
    os_log_info(DemoPluginLogger(), "PluginDestroy plugin=%p", plugin);
    free(plugin);
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismCreate(
    AuthorizationPluginRef plugin,
    AuthorizationEngineRef engine,
    AuthorizationMechanismId mechanismId,
    AuthorizationMechanismRef *mechanism
) {
    if (plugin == NULL || mechanism == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismCreate invalid input plugin=%p mechanism=%p", plugin, mechanism);
        return errAuthorizationInternal;
    }

    DemoMechanismContext *context = calloc(1, sizeof(DemoMechanismContext));
    if (context == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismCreate allocation failed");
        return errAuthorizationInternal;
    }

    context->plugin = (DemoPluginContext *)plugin;
    context->engine = engine;
    *mechanism = context;

    os_log_info(
        DemoPluginLogger(),
        "MechanismCreate mechanismId=%{public}s engine=%p mechanism=%p",
        mechanismId != NULL ? mechanismId : "(null)",
        engine,
        context
    );
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismInvoke(AuthorizationMechanismRef mechanism) {
    DemoMechanismContext *context = (DemoMechanismContext *)mechanism;
    if (context == NULL || context->plugin == NULL || context->plugin->callbacks == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke invalid context mechanism=%p", mechanism);
        return errAuthorizationInternal;
    }

    if (context->plugin->callbacks->SetResult == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke missing SetResult callback");
        return errAuthorizationInternal;
    }

    char *shellPath = DemoCopyEnvironmentValue("DEMO_LOGIN_SHELL_PATH", kDemoLoginShellDefaultPath);
    char *resultPath = DemoCreateResultPath();
    char *idpBaseURL = DemoCopyEnvironmentValue("DEMO_LOGIN_PLUGIN_IDP_BASE_URL", kDemoLoginPluginIDPDefaultURL);
    DemoHelperDecision decision = {
        .result = kAuthorizationResultAllow,
        .username = NULL,
        .password = NULL,
        .message = NULL,
    };

    if (shellPath == NULL || resultPath == NULL || idpBaseURL == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke failed to allocate shell launch inputs");
        free(shellPath);
        free(resultPath);
        free(idpBaseURL);
        DemoHelperDecisionReset(&decision);
        os_log_info(DemoPluginLogger(), "MechanismInvoke pre-login shell unavailable, allowing native login");
        return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultAllow);
    }

    os_log_info(
        DemoPluginLogger(),
        "MechanismInvoke showing pre-login shell engine=%p mechanism=%p shell=%{public}s",
        context->engine,
        mechanism,
        shellPath
    );

    OSStatus status = DemoRunLoginShell(context, shellPath, resultPath, idpBaseURL, &decision);
    unlink(resultPath);
    free(shellPath);
    free(resultPath);
    free(idpBaseURL);

    if (status != errAuthorizationSuccess) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke helper flow failed status=%d", (int)status);
        DemoHelperDecisionReset(&decision);
        os_log_info(DemoPluginLogger(), "MechanismInvoke pre-login shell unavailable, allowing native login");
        return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultAllow);
    }

    if (decision.result == kAuthorizationResultAllow) {
        status = DemoPluginApplyCredentials(
            context->plugin->callbacks,
            context->engine,
            decision.username,
            decision.password
        );
        if (status != errAuthorizationSuccess) {
            os_log_error(DemoPluginLogger(), "MechanismInvoke failed applying credentials status=%d", (int)status);
            DemoHelperDecisionReset(&decision);
            return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultDeny);
        }
    }

    AuthorizationResult finalResult = decision.result;
    os_log_info(
        DemoPluginLogger(),
        "MechanismInvoke completed result=%u username=%{public}s",
        (unsigned)finalResult,
        decision.username != NULL ? decision.username : "(null)"
    );
    DemoHelperDecisionReset(&decision);
    return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, finalResult);
}

static OSStatus DemoMechanismDeactivate(AuthorizationMechanismRef mechanism) {
    DemoMechanismContext *context = (DemoMechanismContext *)mechanism;
    if (context == NULL || context->plugin == NULL || context->plugin->callbacks == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismDeactivate invalid context mechanism=%p", mechanism);
        return errAuthorizationInternal;
    }

    if (context->plugin->callbacks->DidDeactivate != NULL) {
        os_log_info(DemoPluginLogger(), "MechanismDeactivate engine=%p mechanism=%p", context->engine, mechanism);
        return context->plugin->callbacks->DidDeactivate(context->engine);
    }

    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDestroy(AuthorizationMechanismRef mechanism) {
    os_log_info(DemoPluginLogger(), "MechanismDestroy mechanism=%p", mechanism);
    free(mechanism);
    return errAuthorizationSuccess;
}

static const AuthorizationPluginInterface kDemoPluginInterface = {
    .version = kAuthorizationPluginInterfaceVersion,
    .PluginDestroy = DemoPluginDestroy,
    .MechanismCreate = DemoMechanismCreate,
    .MechanismInvoke = DemoMechanismInvoke,
    .MechanismDeactivate = DemoMechanismDeactivate,
    .MechanismDestroy = DemoMechanismDestroy,
};

AuthorizationPluginRef DemoCreatePlugin(void) {
    return calloc(1, sizeof(DemoPluginContext));
}

OSStatus AuthorizationPluginCreate(
    const AuthorizationCallbacks *callbacks,
    AuthorizationPluginRef *outPlugin,
    const AuthorizationPluginInterface **outPluginInterface
) {
    if (outPlugin == NULL || outPluginInterface == NULL) {
        os_log_error(
            DemoPluginLogger(),
            "AuthorizationPluginCreate invalid outputs plugin=%p interface=%p",
            outPlugin,
            outPluginInterface
        );
        return errAuthorizationInternal;
    }

    DemoPluginContext *context = (DemoPluginContext *)DemoCreatePlugin();
    if (context == NULL) {
        os_log_error(DemoPluginLogger(), "AuthorizationPluginCreate allocation failed");
        return errAuthorizationInternal;
    }

    context->callbacks = callbacks;
    *outPlugin = context;
    *outPluginInterface = &kDemoPluginInterface;

    os_log_info(
        DemoPluginLogger(),
        "AuthorizationPluginCreate callbacks=%p plugin=%p interface=%p",
        callbacks,
        context,
        &kDemoPluginInterface
    );
    return errAuthorizationSuccess;
}
