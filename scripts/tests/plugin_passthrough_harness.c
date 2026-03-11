#include <Security/AuthorizationPlugin.h>
#include <Security/AuthorizationTags.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern OSStatus AuthorizationPluginCreate(
    const AuthorizationCallbacks *callbacks,
    AuthorizationPluginRef *outPlugin,
    const AuthorizationPluginInterface **outPluginInterface
);

static int g_set_result_calls = 0;
static AuthorizationResult g_last_result = kAuthorizationResultUndefined;
static AuthorizationEngineRef g_last_engine = NULL;
static int g_context_username_set = 0;
static int g_context_password_set = 0;
static int g_hint_shared_set = 0;
static char g_context_username[256] = {0};
static char g_context_password[256] = {0};

static OSStatus FakeSetResult(AuthorizationEngineRef inEngine, AuthorizationResult inResult) {
    g_set_result_calls += 1;
    g_last_engine = inEngine;
    g_last_result = inResult;
    return errAuthorizationSuccess;
}

static OSStatus FakeSetContextValue(
    AuthorizationEngineRef inEngine,
    AuthorizationString inKey,
    AuthorizationContextFlags inContextFlags,
    const AuthorizationValue *inValue
) {
    (void)inEngine;
    (void)inContextFlags;

    if (inKey == NULL || inValue == NULL || inValue->data == NULL) {
        return errAuthorizationSuccess;
    }

    if (strcmp(inKey, kAuthorizationEnvironmentUsername) == 0) {
        size_t length = inValue->length < sizeof(g_context_username) - 1 ? inValue->length : sizeof(g_context_username) - 1;
        memcpy(g_context_username, inValue->data, length);
        g_context_username[length] = '\0';
        g_context_username_set = 1;
    } else if (strcmp(inKey, kAuthorizationEnvironmentPassword) == 0) {
        size_t length = inValue->length < sizeof(g_context_password) - 1 ? inValue->length : sizeof(g_context_password) - 1;
        memcpy(g_context_password, inValue->data, length);
        g_context_password[length] = '\0';
        g_context_password_set = 1;
    }

    return errAuthorizationSuccess;
}

static OSStatus FakeSetHintValue(
    AuthorizationEngineRef inEngine,
    AuthorizationString inKey,
    const AuthorizationValue *inValue
) {
    (void)inEngine;
    (void)inValue;

    if (inKey != NULL && strcmp(inKey, kAuthorizationEnvironmentShared) == 0) {
        g_hint_shared_set = 1;
    }

    return errAuthorizationSuccess;
}

static OSStatus FakeUnsupported(void) {
    return errAuthorizationSuccess;
}

int main(void) {
    const char *expected_result = getenv("EXPECT_RESULT");
    const char *expected_username = getenv("EXPECT_CONTEXT_USERNAME");
    const char *expected_password = getenv("EXPECT_CONTEXT_PASSWORD");

    AuthorizationCallbacks callbacks = {
        .version = kAuthorizationCallbacksVersion,
        .SetResult = FakeSetResult,
        .RequestInterrupt = (void *)FakeUnsupported,
        .DidDeactivate = (void *)FakeUnsupported,
        .GetContextValue = NULL,
        .SetContextValue = FakeSetContextValue,
        .GetHintValue = NULL,
        .SetHintValue = FakeSetHintValue,
        .GetArguments = NULL,
        .GetSessionId = NULL,
        .GetImmutableHintValue = NULL,
        .GetLAContext = NULL,
        .GetTokenIdentities = NULL,
        .GetTKTokenWatcher = NULL,
        .RemoveContextValue = NULL,
        .RemoveHintValue = NULL,
    };

    AuthorizationPluginRef plugin = NULL;
    const AuthorizationPluginInterface *pluginInterface = NULL;
    OSStatus status = AuthorizationPluginCreate(&callbacks, &plugin, &pluginInterface);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "AuthorizationPluginCreate failed: %d\n", (int)status);
        return 1;
    }

    if (plugin == NULL || pluginInterface == NULL) {
        fprintf(stderr, "Plugin handshake returned null pointers\n");
        return 1;
    }

    AuthorizationEngineRef engine = (AuthorizationEngineRef)(uintptr_t)0x1234;
    AuthorizationMechanismRef mechanism = NULL;
    status = pluginInterface->MechanismCreate(plugin, engine, "login", &mechanism);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "MechanismCreate failed: %d\n", (int)status);
        return 1;
    }

    if (mechanism == NULL) {
        fprintf(stderr, "MechanismCreate returned null mechanism\n");
        return 1;
    }

    status = pluginInterface->MechanismInvoke(mechanism);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "MechanismInvoke failed: %d\n", (int)status);
        return 1;
    }

    if (g_set_result_calls != 1) {
        fprintf(stderr, "Expected SetResult once, got %d\n", g_set_result_calls);
        return 1;
    }

    AuthorizationResult desired = kAuthorizationResultAllow;
    if (expected_result != NULL) {
        if (strcmp(expected_result, "deny") == 0) {
            desired = kAuthorizationResultDeny;
        } else if (strcmp(expected_result, "userCanceled") == 0) {
            desired = kAuthorizationResultUserCanceled;
        }
    }

    if (g_last_result != desired) {
        fprintf(stderr, "Expected result %u, got %u\n", (unsigned)desired, (unsigned)g_last_result);
        return 1;
    }

    if (g_last_engine != engine) {
        fprintf(stderr, "Engine mismatch after SetResult\n");
        return 1;
    }

    if (desired == kAuthorizationResultAllow) {
        if (expected_username != NULL && (!g_context_username_set || strcmp(expected_username, g_context_username) != 0)) {
            fprintf(stderr, "Expected username context '%s', got '%s'\n", expected_username, g_context_username);
            return 1;
        }

        if (expected_password != NULL && (!g_context_password_set || strcmp(expected_password, g_context_password) != 0)) {
            fprintf(stderr, "Expected password context '%s', got '%s'\n", expected_password, g_context_password);
            return 1;
        }

        if ((expected_username != NULL || expected_password != NULL) && !g_hint_shared_set) {
            fprintf(stderr, "Expected shared hint to be set for allow result\n");
            return 1;
        }
    }

    status = pluginInterface->MechanismDestroy(mechanism);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "MechanismDestroy failed: %d\n", (int)status);
        return 1;
    }

    status = pluginInterface->PluginDestroy(plugin);
    if (status != errAuthorizationSuccess) {
        fprintf(stderr, "PluginDestroy failed: %d\n", (int)status);
        return 1;
    }

    return 0;
}
