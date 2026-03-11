# Known Limitations

## Current revision

This revision implements the supporting logic and local demo IdP for the Jamf-style path, and now includes a minimal pass-through Authorization Services plug-in that can be staged into the system auth chain for lab validation.

Implemented:

- fixed-account local demo IdP over HTTP
- shared account mapping storage
- offline login grace evaluation
- token refresh decision logic
- password sync decision logic
- native AppKit and SwiftUI login shell executable
- Authorization Services plug-in entry-point with native-login pass-through behavior
- broker executable that emits plug-in decision JSON
- real bundle packaging for `DemoLoginPlugin.bundle`
- real staging install and uninstall into a chosen filesystem root
- authorizationdb transform and restore scripts for lab-safe integration
- install, uninstall, and native-restore dry-run scripts

Not yet implemented:

- real LoginWindow UI takeover inside the system login environment
- privileged local account creation and password rotation daemon
- SecureToken and FileVault handling
- full auth database takeover that replaces the native username/password prompt

## Practical meaning

You can validate:

- the IdP interface shape
- account and token data contracts
- daemon-backed login decision flow for a future plug-in process
- bundle packaging and staged filesystem installation layout
- how the live `system.login.console` rule would be transformed for this plug-in
- that the minimal plug-in can be loaded without stalling the native login chain
- the state and policy logic that the future LoginWindow component will call
- the target system paths and uninstall flow shape

You cannot yet validate:

- an immediate custom SSO UI takeover before the native login prompt
- bound local account creation from the real login screen
- password rotation against a real local account
- a Jamf Connect-like replacement of the system login prompt with the SwiftUI shell

## Recommended next step

The next meaningful milestone is to add:

1. a real LoginWindow-hosted UI handoff from the Authorization Services plug-in
2. broker-to-plugin state exchange that can drive the shell inside the system login session
3. a privileged daemon contract for mapping, password sync, and local account mutation
