# Pre-Login Button Demo Design

**Date:** 2026-03-11

## Goal

Replace the pre-login text-entry form with a button-only demo panel so the Authorization plug-in can prove three stable paths inside `loginwindow`:

- allow login and continue the plug-in chain
- deny validation and remain on the pre-login panel
- cancel and return to the native macOS login UI

## Context

The current AppKit pre-login helper successfully launches from the Authorization plug-in, but any `NSTextField` or `NSSecureTextField` usage still triggers text-service and ViewBridge behavior that stalls the login flow and causes the plug-in timeout fallback.

The next proof point is not free-form credential entry. It is stable plug-in behavior with a minimal pre-login UI that avoids the macOS text input stack entirely.

## Chosen Approach

Use a fixed AppKit window with explanatory copy and three buttons:

- `Validate Success`
- `Validate Failure`
- `Back To macOS Login`

Each button maps to a preconfigured result rather than collecting user input.

## Behavior

### Validate Success

Return `.allow(localShortName: "demouser", authSource: .fallback)`.

This verifies that the plug-in can:

- display the pre-login window
- accept a user action
- write an allow result file
- release control back to the Authorization mechanism for success handling

### Validate Failure

Return `.deny(message: "Demo validation failed.")`.

The panel should remain visible and update its status label with the deny message. This verifies that a handled failure does not tear down the UI or force an unintended fallback.

### Back To macOS Login

Return `.userCanceled`.

The helper should exit after writing the result payload, and the plug-in should map that result to its deny/cancel path so `loginwindow` returns to the native macOS login page immediately, without waiting for timeout.

## UI Structure

The pre-login window will contain:

- title
- short explanatory subtitle
- status label
- vertical stack of action buttons

There will be no editable controls, field editor configuration, or first responder handoff to text input views.

## State Model

The current pre-login view model stores `username` and `password` and exposes `submit()`. That will be replaced with action-based submission:

- the view model accepts a closure that resolves a selected demo action to `PreLoginAuthResult`
- button taps call `submit(action:)`
- while submitting, all buttons are disabled
- deny keeps the window open and surfaces the error
- allow and cancel complete the helper flow

## Testing

Targeted unit coverage should prove:

- success action completes with `.allow(...)`
- failure action leaves `completedResult` unset and surfaces the deny message
- cancel action completes with `.userCanceled`
- the controller exposes the three required buttons
- the controller shows the default explanatory status text and updates the failure text
- no test depends on `NSTextField` or `NSSecureTextField`

## Non-Goals

- free-form username/password entry
- `WKWebView` or browser-based login
- reworking the broader interactive SwiftUI login shell
- changing the Authorization plug-in mechanism contract
