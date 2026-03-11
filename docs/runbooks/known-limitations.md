# Known Limitations

## Current revision

This revision implements the supporting logic and local demo IdP for the Jamf-style path, and now includes a LoginWindow-hosted Authorization Services plug-in view for lab validation.

Implemented:

- fixed-account local demo IdP over HTTP
- shared account mapping storage
- offline login grace evaluation
- token refresh decision logic
- password sync decision logic
- native AppKit and SwiftUI login shell executable
- Authorization Services plug-in entry-point with a LoginWindow-hosted pre-login UI
- real bundle packaging for `DemoLoginPlugin.bundle`
- real staging install and uninstall into a chosen filesystem root
- authorizationdb transform and restore scripts for lab-safe integration
- install, uninstall, and native-restore dry-run scripts

Not yet implemented:

- privileged local account creation and password rotation daemon
- SecureToken and FileVault handling
- full live account binding / account creation flow from the system login environment

## Practical meaning

You can validate:

- the IdP interface shape
- account and token data contracts
- bundle packaging and staged filesystem installation layout
- how the live `system.login.console` rule would be transformed for this plug-in
- that the plug-in can render a custom SSO view inside the LoginWindow-hosted login flow
- that successful demo SSO validation can pass a local short name and password into the native login chain
- the target system paths and uninstall flow shape

You cannot yet validate:

- bound local account creation from the real login screen
- password rotation against a real local account
- SecureToken/FileVault follow-up after a successful pre-login SSO validation

## Recommended next step

The next meaningful milestone is to add:

1. live account binding and local account creation paths inside the Authorization plug-in flow
2. privileged daemon integration for password sync and local account mutation
3. SecureToken and FileVault follow-up after successful SSO validation
