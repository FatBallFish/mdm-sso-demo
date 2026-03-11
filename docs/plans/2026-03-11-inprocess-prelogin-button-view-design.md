# In-Process Pre-Login Button View Design

**Date:** 2026-03-11

## Goal

Abandon the external `DemoLoginShell.app` path for the first pre-login interaction and move the demo back into the `SecurityAgent` plug-in view itself, using a button-only UI that can:

- allow login
- deny and remain on the custom panel
- cancel and return to the native macOS login page

## Root Cause Summary

Recent live testing on the remote machine proved:

- `system.login.console` ordering is correct
- the Authorization mechanism is invoked
- the plug-in times out waiting for the external helper result file

The external AppKit helper can launch as a normal desktop app after login, but in the pre-login host it does not reliably complete GUI check-in or reach its own observable startup logs. That makes the external-helper architecture untrustworthy for the first authentication surface.

An earlier revision already demonstrated that an in-process `SecurityAgent` plug-in view could appear, even though it later stalled because of text-input related services. That is the more credible base to continue from.

## Chosen Approach

Render the pre-login UI directly inside `DemoAuthorizationLoginView`, and reduce it to static text plus three actions:

- `Validate Success`
- `Validate Failure`
- `Back To macOS Login`

No editable text fields. No secure text fields. No HTTP pre-login call. No external helper for the first screen.

## Alternatives Considered

### 1. Keep the external helper and continue hardening launch behavior

Rejected.

We already proved the plug-in can spawn a helper process and still fail to reach a visible, actionable pre-login state. Further work here would still depend on unsupported or fragile loginwindow-hosted app behavior.

### 2. Use the existing in-process plug-in view, but keep username/password fields

Rejected.

This is the exact interaction mode that previously triggered the text-input, cursor UI, and ViewBridge family of failures. Returning to it would knowingly reintroduce the unstable dependency chain.

### 3. Use an in-process button-only plug-in view

Chosen.

This preserves the one architecture that has already shown visible UI potential while removing the input path most likely to stall the host.

## UI Structure

The custom plug-in view will contain:

- title
- short explanatory subtitle
- status label
- three action buttons in the content view

The built-in `SecurityAgent` login and cancel buttons will be disabled and unused for this path. Interaction will be driven only by the custom buttons.

## Behavior

### Validate Success

Call `DemoPluginApplyCredentials` with:

- local short name: `demouser`
- password: `DemoPass123!`

Then set the mechanism result to `kAuthorizationResultAllow`.

### Validate Failure

Do not call `DemoPluginApplyCredentials`.

Update the status label to `Demo validation failed.` and keep the custom view active and interactive.

### Back To macOS Login

Do not call `DemoPluginApplyCredentials`.

Set the mechanism result to `kAuthorizationResultUserCanceled` so the login flow returns to the native macOS login UI immediately instead of waiting for timeout.

## Data Flow

The plug-in view will no longer depend on:

- seeded account lookup by username/password
- HTTP health checks
- HTTP login calls

For this milestone, the plug-in view becomes a deterministic demo switchboard. The existing external helper remains in the repo only for post-login or non-prelogin experimentation, not as the primary loginwindow UI path.

## Logging

The in-process plug-in view should log action-level events with the existing `com.demo.sso.login-plugin` subsystem, for example:

- success button pressed
- failure button pressed
- cancel button pressed
- allow path applied credentials

This is needed so future remote debugging does not depend on helper process logs.

## Testing

The minimum regression checks are:

- source no longer contains `NSTextField` / `NSSecureTextField` editable controls in `PluginLoginView.m`
- source contains the three custom button labels
- source contains the new status copy and action logs
- existing plug-in bundle smoke still passes
- focused package tests still pass

## Non-Goals

- free-form username/password entry
- demo IdP validation from the first pre-login screen
- WebView or browser-based login
- restoring the external helper as the primary pre-login UI
