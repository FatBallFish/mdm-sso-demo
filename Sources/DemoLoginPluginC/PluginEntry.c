#include "DemoLoginPlugin.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Security/AuthorizationPlugin.h>
#include <Security/AuthorizationTags.h>
#include <os/log.h>
#include <stdlib.h>
#include <string.h>

typedef struct DemoPluginContext {
    const AuthorizationCallbacks *callbacks;
} DemoPluginContext;

typedef struct DemoMechanismContext {
    DemoPluginContext *plugin;
    AuthorizationEngineRef engine;
    void *loginViewHandle;
} DemoMechanismContext;

static os_log_t DemoPluginLogger(void) {
    static os_log_t logger = NULL;
    if (logger == NULL) {
        logger = os_log_create("com.demo.sso.login-plugin", "authorization");
    }
    return logger;
}

static OSStatus DemoSetStringContextValue(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    AuthorizationString key,
    const char *value
) {
    if (callbacks == NULL || callbacks->SetContextValue == NULL || engine == NULL || key == NULL || value == NULL) {
        return errAuthorizationInternal;
    }

    AuthorizationValue authValue = {
        .length = strlen(value),
        .data = (void *)value,
    };

    return callbacks->SetContextValue(engine, key, kAuthorizationContextFlagVolatile, &authValue);
}

static OSStatus DemoSetStringHintValue(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    AuthorizationString key,
    const char *value
) {
    if (callbacks == NULL || callbacks->SetHintValue == NULL || engine == NULL || key == NULL || value == NULL) {
        return errAuthorizationInternal;
    }

    AuthorizationValue authValue = {
        .length = strlen(value),
        .data = (void *)value,
    };

    return callbacks->SetHintValue(engine, key, &authValue);
}

static OSStatus DemoSetSharedHintValue(const AuthorizationCallbacks *callbacks, AuthorizationEngineRef engine) {
    if (callbacks == NULL || callbacks->SetHintValue == NULL || engine == NULL) {
        return errAuthorizationInternal;
    }

    static const char sharedMarker[] = "";
    AuthorizationValue authValue = {
        .length = 0,
        .data = (void *)sharedMarker,
    };

    return callbacks->SetHintValue(engine, kAuthorizationEnvironmentShared, &authValue);
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

    OSStatus status = DemoSetStringContextValue(callbacks, engine, kAuthorizationEnvironmentUsername, username);
    if (status != errAuthorizationSuccess) {
        return status;
    }

    status = DemoSetStringContextValue(callbacks, engine, kAuthorizationEnvironmentPassword, password);
    if (status != errAuthorizationSuccess) {
        return status;
    }

    if (callbacks->SetHintValue != NULL) {
        status = DemoSetStringHintValue(callbacks, engine, kAuthorizationEnvironmentUsername, username);
        if (status != errAuthorizationSuccess) {
            return status;
        }

        status = DemoSetStringHintValue(callbacks, engine, kAuthorizationEnvironmentPassword, password);
        if (status != errAuthorizationSuccess) {
            return status;
        }

        status = DemoSetSharedHintValue(callbacks, engine);
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

static OSStatus DemoPluginRunTestMode(DemoMechanismContext *context, const char *mode) {
    if (context == NULL || context->plugin == NULL || context->plugin->callbacks == NULL || mode == NULL) {
        return errAuthorizationInternal;
    }

    const char *username = getenv("DEMO_PLUGIN_TEST_USERNAME");
    const char *password = getenv("DEMO_PLUGIN_TEST_PASSWORD");
    if (username == NULL || username[0] == '\0') {
        username = "demouser";
    }
    if (password == NULL || password[0] == '\0') {
        password = "DemoPass123!";
    }

    if (strcmp(mode, "allow") == 0) {
        OSStatus status = DemoPluginApplyCredentials(context->plugin->callbacks, context->engine, username, password);
        if (status != errAuthorizationSuccess) {
            return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultDeny);
        }
        return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultAllow);
    }

    if (strcmp(mode, "cancel") == 0) {
        return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultUserCanceled);
    }

    return DemoPluginSetAuthorizationResult(context->plugin->callbacks, context->engine, kAuthorizationResultDeny);
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
    context->loginViewHandle = NULL;
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

    const AuthorizationCallbacks *callbacks = context->plugin->callbacks;
    if (callbacks->SetResult == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke missing SetResult callback");
        return errAuthorizationInternal;
    }

    const char *testMode = getenv("DEMO_PLUGIN_TEST_MODE");
    if (testMode != NULL && testMode[0] != '\0') {
        os_log_info(DemoPluginLogger(), "MechanismInvoke test_mode=%{public}s", testMode);
        return DemoPluginRunTestMode(context, testMode);
    }

    if (context->loginViewHandle == NULL) {
        context->loginViewHandle = DemoPluginCreateLoginView(callbacks, context->engine);
    }

    if (context->loginViewHandle == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke failed creating login view");
        return DemoPluginSetAuthorizationResult(callbacks, context->engine, kAuthorizationResultDeny);
    }

    os_log_info(DemoPluginLogger(), "MechanismInvoke showing pre-login view engine=%p mechanism=%p", context->engine, mechanism);
    OSStatus status = DemoPluginDisplayLoginView(context->loginViewHandle);
    if (status != errAuthorizationSuccess) {
        os_log_error(DemoPluginLogger(), "MechanismInvoke displayView failed status=%d", (int)status);
        return DemoPluginSetAuthorizationResult(callbacks, context->engine, kAuthorizationResultDeny);
    }

    // The view completes the mechanism asynchronously when the user submits or cancels.
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDeactivate(AuthorizationMechanismRef mechanism) {
    DemoMechanismContext *context = (DemoMechanismContext *)mechanism;
    if (context == NULL || context->plugin == NULL || context->plugin->callbacks == NULL) {
        os_log_error(DemoPluginLogger(), "MechanismDeactivate invalid context mechanism=%p", mechanism);
        return errAuthorizationInternal;
    }

    if (context->loginViewHandle != NULL) {
        DemoPluginDeactivateLoginView(context->loginViewHandle);
    }

    if (context->plugin->callbacks->DidDeactivate != NULL) {
        os_log_info(DemoPluginLogger(), "MechanismDeactivate engine=%p mechanism=%p", context->engine, mechanism);
        return context->plugin->callbacks->DidDeactivate(context->engine);
    }

    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDestroy(AuthorizationMechanismRef mechanism) {
    DemoMechanismContext *context = (DemoMechanismContext *)mechanism;
    os_log_info(DemoPluginLogger(), "MechanismDestroy mechanism=%p", mechanism);

    if (context != NULL) {
        if (context->loginViewHandle != NULL) {
            DemoPluginDestroyLoginView(context->loginViewHandle);
            context->loginViewHandle = NULL;
        }
        free(context);
    }

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
        os_log_error(DemoPluginLogger(), "AuthorizationPluginCreate invalid outputs plugin=%p interface=%p", outPlugin, outPluginInterface);
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
