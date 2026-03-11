# LoginWindow Pre-Login UI Design

## Goal

Build a demo-grade macOS LoginWindow flow where a custom SSO UI appears before the native macOS username/password prompt, prefers validation through the local HTTP demo IdP, falls back to fixed in-process credentials when the IdP is unavailable, and only then allows the native login chain to continue.

## Scope

This design covers one focused milestone:

- show a custom login UI before `loginwindow:login`
- collect username and password inside the plug-in
- validate with local HTTP IdP first
- fall back to fixed test credentials if the IdP is unavailable
- allow the system login chain to continue only after successful validation
- keep the demo stable by limiting the system-login path to already-existing local accounts

This milestone does not cover:

- true local account creation during the real LoginWindow flow
- SecureToken or FileVault unlock integration
- remote IdP infrastructure
- a full Jamf Connect equivalent replacement of every native login behavior

## Constraints

### Login order

The custom plug-in mechanism must execute before `loginwindow:login`. The current authdb transform inserts `DemoLoginPlugin:login,privileged` after `loginwindow:login`, which is why the native login prompt appears first. This design changes the insertion point so the SSO UI becomes the first visible authentication surface.

### Demo stability

The current repo already demonstrates that malformed Authorization plug-in behavior can stall the system login chain. This design keeps the first system-facing milestone conservative:

- use a synchronous plug-in decision model
- allow only existing local accounts
- defer new account creation and password rotation at the system login stage

### IdP availability

The local demo IdP may not be running at the real login moment. The plug-in must therefore not hard-depend on the HTTP server. The design uses:

1. HTTP IdP login as the preferred path
2. fixed in-process fallback credentials when health or login requests fail

This keeps the demo aligned with the desired service-oriented architecture while avoiding a brittle dependency on a separately started background process.

## Architecture

### 1. Authorization plug-in entry point

`DemoLoginPluginC` remains the Authorization Services interface layer. It owns:

- mechanism lifecycle
- unified logging
- the blocking login decision boundary
- the final `allow` / `deny` call into `AuthorizationCallbacks`

The C layer should stay small and delegate all UI and authentication behavior to Swift support code.

### 2. Plug-in UI and authentication bridge

`DemoLoginPluginSupport` gains a new pre-login coordinator responsible for:

- presenting a native AppKit login panel from inside the loginwindow plug-in host
- collecting username and password
- checking local IdP availability
- attempting HTTP login
- falling back to fixed test credentials if the HTTP path is unavailable
- returning a structured login decision back to the C plug-in

The fallback account table should reuse existing fixed demo credentials where possible so that shell, broker, and plug-in tests all exercise the same account set.

### 3. Shared login policy

`DemoShared` continues to hold:

- fixed demo account metadata
- token response and account mapping models
- common decision shapes used by shell, broker, and plug-in support layers

This prevents the plug-in UI path from diverging from the shell and broker demo logic.

### 4. Existing local account continuation

For this milestone, the plug-in supports only SSO identities that map to already-existing local accounts on the test machine. The plug-in flow is:

1. user enters SSO credentials in the custom pre-login UI
2. plug-in validates through HTTP IdP or fixed fallback
3. plug-in resolves a local short name
4. plug-in writes the necessary context for the downstream native login chain
5. plug-in allows the mechanism so native login can continue

If no existing local account mapping is available, the plug-in denies the attempt and shows a clear message. The real LoginWindow path does not attempt account creation in this milestone.

## UI Design

The UI is a native AppKit panel shown directly from the plug-in host:

- title: demo SSO login
- username field
- password field
- sign-in button
- cancel button
- status area for progress and error text
- subtle environment note indicating `HTTP IdP first, local fallback`

The panel should be visually minimal and intentionally closer to the current standalone `DemoLoginShell` than to a browser-based flow. This reduces dependencies and makes the behavior more predictable inside the loginwindow environment.

## Authentication Flow

### Primary path

1. on sign-in, issue `GET /api/health` to `http://127.0.0.1:48080/api/health`
2. if healthy, issue `POST /api/login`
3. on success, continue with local-account resolution

### Fallback path

If either the health check or login request fails due to:

- connection refused
- timeout
- malformed HTTP response
- unavailable local IdP process

the plug-in falls back to an in-process fixed account validator using the seeded demo accounts.

### Failure semantics

- invalid credentials on both paths: stay in the custom UI and show authentication failed
- no local account mapping: stay in the custom UI and explain that only existing local accounts are supported in this milestone
- user cancel: return `kAuthorizationResultUserCanceled`

## LoginWindow Chain Integration

### Authdb transform

`configure-loginwindow-authdb.sh` must change from:

- insert `DemoLoginPlugin:login,privileged` after `loginwindow:login`

to:

- insert `DemoLoginPlugin:login,privileged` before `loginwindow:login`

This is the core change that places the custom SSO UI ahead of the native login UI.

### Authorization context handoff

The plug-in must pass enough context to the downstream native login chain to continue a real login for an existing local account. This milestone assumes:

- the mapping from SSO subject to local short name is available
- the downstream login chain can consume the supplied local identity context

This is the riskiest integration point and must be treated as an iterative validation area during implementation.

## Logging

Unified logging remains mandatory. New log coverage should include:

- pre-login panel shown
- HTTP health check start / success / failure
- HTTP login start / success / failure
- fallback validation start / success / failure
- downstream local-account resolution result
- final allow / deny decision

These logs are required because the loginwindow environment is difficult to debug interactively.

## Testing Strategy

### Automated

- unit tests for HTTP-first / fallback-second decision behavior
- unit tests for fixed credential fallback
- authdb transform smoke test verifying insertion before `loginwindow:login`
- plug-in harness test covering allow / deny / cancel paths
- broker and shell tests kept green to avoid breaking the existing demo workflows

### Manual lab validation

1. install artifacts on a test machine
2. write transformed authdb
3. log out
4. confirm the custom SSO panel appears before the native login prompt
5. test HTTP IdP success path
6. stop the local IdP and confirm fallback credentials still work
7. confirm invalid credentials remain on the custom panel
8. confirm successful login continues into the desktop for an existing mapped local user

## Risks

### 1. Context handoff into native login

The exact downstream data expected by macOS mechanisms is the least certain part of the implementation. This must be validated experimentally on the test machine.

### 2. UI behavior inside loginwindow plug-in host

Some AppKit behaviors that work in a normal app may behave differently in the plug-in host. The implementation should start from a minimal modal panel and avoid unnecessary complexity.

### 3. Local IdP process assumptions

The fallback path avoids hard failure when the local HTTP service is down, but this also means demo behavior can differ between runs. The logs must clearly state whether validation used `http` or `fallback`.

## Recommended Milestone Boundary

The first implementation milestone should ship only when all of the following are true:

- the custom UI appears before the native login prompt
- the login chain no longer stalls
- HTTP-first and fallback auth both work
- only existing local accounts are permitted

After that, the next milestone can revisit account creation, password sync, and SecureToken.
