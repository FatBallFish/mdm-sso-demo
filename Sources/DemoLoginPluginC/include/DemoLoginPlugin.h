#ifndef DEMO_LOGIN_PLUGIN_H
#define DEMO_LOGIN_PLUGIN_H

#include <Security/AuthorizationPlugin.h>

AuthorizationPluginRef DemoCreatePlugin(void);
OSStatus DemoPluginApplyCredentials(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    const char *username,
    const char *password
);
OSStatus DemoPluginSetAuthorizationResult(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine,
    AuthorizationResult result
);
void *DemoPluginCreateLoginView(
    const AuthorizationCallbacks *callbacks,
    AuthorizationEngineRef engine
);
OSStatus DemoPluginDisplayLoginView(void *viewHandle);
void DemoPluginDeactivateLoginView(void *viewHandle);
void DemoPluginDestroyLoginView(void *viewHandle);

#endif
