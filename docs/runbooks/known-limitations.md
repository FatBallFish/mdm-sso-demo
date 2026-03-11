# Known Limitations

## Current revision

This revision implements the supporting logic and local demo IdP for the Jamf-style path, but it does not yet install a real macOS LoginWindow authentication plug-in.

Implemented:

- fixed-account local demo IdP over HTTP
- shared account mapping storage
- offline login grace evaluation
- token refresh decision logic
- password sync decision logic
- native AppKit and SwiftUI login shell executable
- Authorization Services plug-in entry-point skeleton
- broker executable that emits plug-in decision JSON
- real bundle packaging for `DemoLoginPlugin.bundle`
- real staging install and uninstall into a chosen filesystem root
- authorizationdb transform and restore scripts for lab-safe integration
- install, uninstall, and native-restore dry-run scripts

Not yet implemented:

- packaged Authorization Services plug-in bundle under `/Library/Security/SecurityAgentPlugins/`
- real LoginWindow UI takeover inside the system login environment
- privileged local account creation and password rotation daemon
- SecureToken and FileVault handling
- real auth database switching

## Practical meaning

You can validate:

- the IdP interface shape
- account and token data contracts
- daemon-backed login decision flow for a future plug-in process
- bundle packaging and staged filesystem installation layout
- how the live `system.login.console` rule would be transformed for this plug-in
- the state and policy logic that the future LoginWindow component will call
- the target system paths and uninstall flow shape

You cannot yet validate:

- actual macOS login interception
- bound local account creation from the real login screen
- password rotation against a real local account
- a live `security authorizationdb write` to the real system rule, because the current scripts stage and preview the change rather than applying it automatically

## Recommended next step

The next meaningful milestone is to add:

1. a minimal Authorization Services plug-in target
2. a thin native login UI shell
3. a privileged daemon contract for mapping and password sync
