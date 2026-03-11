#include <Security/AuthorizationPlugin.h>
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

static OSStatus FakeSetResult(AuthorizationEngineRef inEngine, AuthorizationResult inResult) {
    g_set_result_calls += 1;
    g_last_engine = inEngine;
    g_last_result = inResult;
    return errAuthorizationSuccess;
}

static OSStatus FakeUnsupported(void) {
    return errAuthorizationSuccess;
}

int main(void) {
    AuthorizationCallbacks callbacks = {
        .version = kAuthorizationCallbacksVersion,
        .SetResult = FakeSetResult,
        .RequestInterrupt = (void *)FakeUnsupported,
        .DidDeactivate = (void *)FakeUnsupported,
        .GetContextValue = NULL,
        .SetContextValue = NULL,
        .GetHintValue = NULL,
        .SetHintValue = NULL,
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

    if (g_last_result != kAuthorizationResultAllow) {
        fprintf(stderr, "Expected allow result, got %u\n", (unsigned)g_last_result);
        return 1;
    }

    if (g_last_engine != engine) {
        fprintf(stderr, "Engine mismatch after SetResult\n");
        return 1;
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
