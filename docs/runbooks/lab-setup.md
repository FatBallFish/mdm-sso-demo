# Lab Setup

## Goal

Prepare a local macOS lab for the Jamf-style LoginWindow SSO demo scaffold.

## Current implemented pieces

- Swift package with shared login policy and mapping storage
- Local demo IDP service with fixed accounts and refresh token support
- Native AppKit and SwiftUI login shell executable
- Authorization Services plug-in compile skeleton
- Account sync service scaffold with cached offline login and account binding flow
- Broker executable that returns plug-in-friendly JSON login decisions
- Dry-run install, uninstall, and native restore scripts

## Fixed demo accounts

| Username | Password | Local short name |
| --- | --- | --- |
| `demo.user` | `DemoPass123!` | `demouser` |
| `it.admin` | `AdminPass123!` | `itadmin` |
| `qa.user` | `QAPass123!` | `qauser` |

## Start the local IDP

```bash
./scripts/start-demo-idp.sh
```

The service listens on `127.0.0.1:48080` by default and exposes:

- `GET /api/health`
- `POST /api/login`
- `POST /api/refresh`

## Smoke test the IDP

```bash
bash scripts/tests/idp_smoke_test.sh
```

## Start the native login shell

```bash
./scripts/start-login-shell.sh
```

This opens a native macOS window that represents the future LoginWindow takeover shell. In the current revision it is a standalone user-session window, not an installed system login component.

Behavior currently available in the shell:

- online sign-in against the local demo IDP
- if a local mapping already exists, return a success state
- if no local mapping exists, switch to an account binding screen
- bind an existing local short name or create a suggested local short name in the demo state store
- offline sign-in using cached password fingerprint and grace window

## Broker-based login decision

```bash
swift run DemoLoginBroker --username demo.user --password DemoPass123!
```

The broker returns JSON for the future LoginWindow plug-in layer, for example:

- `{"action":"promptForAccountBinding","subject":"demo.user"}`
- `{"action":"allowLogin","localShortName":"demouser"}`

## Build the installable plug-in bundle

```bash
./scripts/build-login-plugin-bundle.sh
```

This creates `dist/DemoLoginPlugin.bundle`, which is the first real LoginWindow plug-in artifact produced by the repo.

## Stage install into a lab root

```bash
./scripts/install-jamf-style-demo.sh --root /tmp/demo-sso-lab --no-authdb
```

This performs a real file install into the chosen root:

- `Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle`
- `Library/Application Support/DemoSSO/bin/DemoAccountSyncDaemon`
- `Library/Application Support/DemoSSO/bin/DemoLoginBroker`
- `Library/Application Support/DemoSSO/bin/DemoLoginShell`
- `Library/Application Support/DemoSSO/config/demo-idp.json`

It does not yet modify the system authorization database unless that step is added later.

## Generate authorizationdb integration files

```bash
./scripts/configure-loginwindow-authdb.sh \
  --output-plist /tmp/system.login.console.demo.plist \
  --backup-file /tmp/system.login.console.backup.plist
```

This reads the current `system.login.console` rule, inserts `DemoLoginPlugin:login,privileged` after `loginwindow:login`, and writes:

- a backup plist
- a transformed plist ready for a later `security authorizationdb write`

The current install script uses this flow when `--enable-authdb` is supplied, but stages the files under `Library/Application Support/DemoSSO/authdb/` instead of writing the live database.

## Restore from an authorizationdb backup file

```bash
./scripts/restore-native-loginwindow.sh \
  --backup-file /tmp/system.login.console.backup.plist \
  --output-plist /tmp/system.login.console.restored.plist
```

## Install and uninstall scaffolding

```bash
./scripts/install-jamf-style-demo.sh --dry-run
./scripts/uninstall-jamf-style-demo.sh --dry-run
./scripts/restore-native-loginwindow.sh --dry-run
```

## Next implementation gap

The current revision does not yet install a real LoginWindow plug-in bundle or privileged daemon. The plug-in target compiles, but it is not yet packaged into `/Library/Security/SecurityAgentPlugins/` or wired into the login authentication database.
