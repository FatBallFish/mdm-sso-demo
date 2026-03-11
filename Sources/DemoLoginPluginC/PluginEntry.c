#include "DemoLoginPlugin.h"
#include <CoreFoundation/CoreFoundation.h>
#include <os/log.h>
#include <Security/AuthorizationPlugin.h>
#include <stdlib.h>

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

static OSStatus DemoPluginDestroy(AuthorizationPluginRef plugin) {
    os_log_info(DemoPluginLogger(), "PluginDestroy plugin=%p", plugin);
    if (plugin != NULL) {
        free(plugin);
    }
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismCreate(
    AuthorizationPluginRef plugin,
    AuthorizationEngineRef engine,
    AuthorizationMechanismId mechanismId,
    AuthorizationMechanismRef *mechanism
) {
    (void)mechanismId;

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

    // This demo revision only proves the mechanism handoff. Keep native login flowing.
    os_log_info(DemoPluginLogger(), "MechanismInvoke allow engine=%p mechanism=%p", context->engine, mechanism);
    return context->plugin->callbacks->SetResult(context->engine, kAuthorizationResultAllow);
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

    os_log_info(DemoPluginLogger(), "MechanismDeactivate no-op engine=%p mechanism=%p", context->engine, mechanism);
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDestroy(AuthorizationMechanismRef mechanism) {
    os_log_info(DemoPluginLogger(), "MechanismDestroy mechanism=%p", mechanism);
    if (mechanism != NULL) {
        free(mechanism);
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
    DemoPluginContext *context = calloc(1, sizeof(DemoPluginContext));
    return context;
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
