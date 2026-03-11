# Pre-Login AppKit Shell Design

## Goal

Stabilize the logout/login demo flow by replacing the pre-login SwiftUI shell with a pure AppKit shell, while keeping the existing HTTP-first and fallback authentication logic unchanged.

## Problem Summary

The current pre-login shell is launched successfully by the authorization plug-in, but the test machine logs show repeated `ViewBridge`, `SafariPlatformSupport`, `AppIntents`, and pasteboard-related failures while the shell is active in the loginwindow environment. That is strong evidence that the SwiftUI text-input path is not stable in the pre-login host. The live `authorizationdb` order issue is separate: the test machine still has `DemoLoginPlugin:login` after `loginwindow:login`, so the native login page appears first.

## Design

### 1. Keep the external shell architecture

The authorization plug-in continues to:

- spawn `DemoLoginShell`
- wait for a result plist
- apply local username/password context on `allow`
- safely fall back to native login if the shell fails or times out

This avoids returning to the in-plugin `SFAuthorizationPluginView` path, which already failed on the target machine.

### 2. Replace only the pre-login shell UI layer

`DemoLoginShell` keeps SwiftUI for the normal interactive demo mode, but the plug-in launch mode switches to a dedicated AppKit-only pre-login window:

- `NSWindow`
- `NSTextField` for username
- `NSSecureTextField` for password
- `NSButton` for sign in / cancel
- `NSTextField` for status and errors

The AppKit controller binds to the existing `PreLoginPanelViewModel`, so the authentication contract remains unchanged.

### 3. Add shell lifecycle logging

The pre-login shell should log:

- process launch mode
- AppKit window creation
- first window show
- submit / cancel actions
- completion result write

This gives us evidence when debugging the loginwindow host remotely.

### 4. Add plug-in timeout protection

The plug-in should no longer wait forever for the shell. It will:

- poll the child process with a bounded timeout
- kill the helper if the timeout expires
- log the timeout
- allow the native login chain to continue

This prevents another stuck login chain if the shell hangs again.

### 5. Keep authdb ordering explicit

The intended live order remains:

1. `DemoLoginPlugin:login`
2. `loginwindow:login`
3. `builtin:login-begin`

The code change here is already done locally, but the test machine must still rewrite the live `authorizationdb` rule for that ordering to take effect.

## Non-Goals

- do not attempt FileVault pre-boot takeover
- do not add WebView or browser-based UI
- do not change the HTTP/fallback authentication policy
- do not add local account creation or SecureToken handling in this milestone

## Verification

- add a unit test for the AppKit pre-login controller button enablement
- add a smoke test for shell timeout fallback
- keep existing plug-in passthrough smoke green
- re-check the target machine logs after reinstall
