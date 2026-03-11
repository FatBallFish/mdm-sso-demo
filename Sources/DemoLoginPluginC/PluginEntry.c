#include "DemoLoginPlugin.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Security/AuthorizationPlugin.h>

typedef struct DemoPluginContext {
    const AuthorizationCallbacks *callbacks;
} DemoPluginContext;

static OSStatus DemoPluginDestroy(AuthorizationPluginRef plugin) {
    if (plugin != NULL) {
        CFRelease(plugin);
    }
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismCreate(
    AuthorizationPluginRef plugin,
    AuthorizationEngineRef engine,
    AuthorizationMechanismId mechanismId,
    AuthorizationMechanismRef *mechanism
) {
    (void)plugin;
    (void)engine;
    (void)mechanismId;
    *mechanism = NULL;
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismInvoke(AuthorizationMechanismRef mechanism) {
    (void)mechanism;
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDeactivate(AuthorizationMechanismRef mechanism) {
    (void)mechanism;
    return errAuthorizationSuccess;
}

static OSStatus DemoMechanismDestroy(AuthorizationMechanismRef mechanism) {
    (void)mechanism;
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
    return (AuthorizationPluginRef)&kDemoPluginInterface;
}

OSStatus AuthorizationPluginCreate(
    const AuthorizationCallbacks *callbacks,
    AuthorizationPluginRef *outPlugin,
    const AuthorizationPluginInterface **outPluginInterface
) {
    (void)callbacks;
    if (outPlugin == NULL || outPluginInterface == NULL) {
        return errAuthorizationInternal;
    }

    *outPlugin = DemoCreatePlugin();
    *outPluginInterface = &kDemoPluginInterface;
    return errAuthorizationSuccess;
}
