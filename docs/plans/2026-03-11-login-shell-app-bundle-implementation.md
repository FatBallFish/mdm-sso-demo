# DemoLoginShell App Bundle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the pre-login helper from a bare executable with a real `DemoLoginShell.app` so the loginwindow-hosted AppKit flow has a valid main bundle identity and fewer pre-login host incompatibilities.

**Architecture:** Keep the Authorization plug-in architecture unchanged, but change the helper packaging and installation shape. The plug-in will launch `DemoLoginShell.app/Contents/MacOS/DemoLoginShell`, the install script will stage a real app bundle under `/Library/Application Support/DemoSSO/bin/`, and the AppKit process will proactively disable relaunch/restoration behaviors that are inappropriate in the loginwindow environment.

**Tech Stack:** SwiftPM, AppKit, C Authorization plug-in, bash install/build scripts, XCTest smoke tests.

---

### Task 1: Add failing tests for app-bundle installation and plug-in default path

**Files:**
- Modify: `scripts/tests/install_root_smoke.sh`
- Modify: `scripts/tests/install_dry_run_smoke.sh`
- Modify: `scripts/tests/plugin_logging_smoke.sh`

**Step 1: Write the failing test**

Update the smoke tests so they expect:
- install output mentions `DemoLoginShell.app`
- staged install contains `bin/DemoLoginShell.app/Contents/MacOS/DemoLoginShell`
- plug-in source default path points to the app bundle executable

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/install_root_smoke.sh`
Expected: FAIL because install script still copies a bare `DemoLoginShell` binary.

Run: `bash scripts/tests/install_dry_run_smoke.sh`
Expected: FAIL because dry-run output still mentions only `DemoLoginShell`.

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: FAIL because plug-in source still points at `/Library/Application Support/DemoSSO/bin/DemoLoginShell`.

**Step 3: Commit**

```bash
git add scripts/tests/install_root_smoke.sh scripts/tests/install_dry_run_smoke.sh scripts/tests/plugin_logging_smoke.sh
git commit -m "test: cover app-bundled login shell install"
```

### Task 2: Build and install `DemoLoginShell.app`

**Files:**
- Create: `scripts/build-login-shell-app.sh`
- Modify: `scripts/install-jamf-style-demo.sh`
- Modify: `scripts/uninstall-jamf-style-demo.sh`

**Step 1: Write minimal implementation**

Add a helper build script that:
- creates `DemoLoginShell.app/Contents/MacOS/`
- copies the SwiftPM-built `DemoLoginShell` executable into the bundle
- writes a minimal `Contents/Info.plist`
- ad-hoc signs the app if `codesign` is available
- clears quarantine xattrs if present

Update install/uninstall scripts so they:
- stage/remove `DemoLoginShell.app`
- report the new path in dry-run output

**Step 2: Run targeted verification**

Run: `bash scripts/tests/install_root_smoke.sh`
Expected: PASS

Run: `bash scripts/tests/install_dry_run_smoke.sh`
Expected: PASS

**Step 3: Commit**

```bash
git add scripts/build-login-shell-app.sh scripts/install-jamf-style-demo.sh scripts/uninstall-jamf-style-demo.sh scripts/tests/install_root_smoke.sh scripts/tests/install_dry_run_smoke.sh
git commit -m "build: package login shell as app bundle"
```

### Task 3: Point the plug-in at the app bundle executable

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginEntry.c`

**Step 1: Write minimal implementation**

Change the plug-in default helper path to:

```c
static const char *kDemoLoginShellDefaultPath =
    "/Library/Application Support/DemoSSO/bin/DemoLoginShell.app/Contents/MacOS/DemoLoginShell";
```

Keep the environment override behavior unchanged.

**Step 2: Run targeted verification**

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: PASS

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`
Expected: PASS

**Step 3: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginEntry.c scripts/tests/plugin_logging_smoke.sh
git commit -m "fix: launch app-bundled login shell from plugin"
```

### Task 4: Disable relaunch and restoration behaviors in the AppKit helper

**Files:**
- Modify: `Sources/DemoLoginShell/main.swift`
- Modify: `Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift`
- Test: `Tests/DemoLoginShellSupportTests/PreLoginWindowSupportTests.swift`

**Step 1: Write the failing test**

Add a small support-level test or smoke assertion around pre-login window configuration so the window is marked non-restorable and the app-level helper path remains compatible with loginwindow use.

**Step 2: Run test to verify it fails**

Run: `swift test --filter PreLoginWindowSupportTests`
Expected: FAIL before the new behavior exists.

**Step 3: Write minimal implementation**

In the AppKit helper startup:
- call `NSApp.disableRelaunchOnLogin()`
- disable automatic window tabbing
- avoid any unnecessary restoration behavior

In the pre-login window setup:
- mark the window non-restorable
- keep pre-login visibility settings intact

**Step 4: Run targeted verification**

Run: `swift test --filter PreLoginWindowSupportTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginShell/main.swift Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift Tests/DemoLoginShellSupportTests/PreLoginWindowSupportTests.swift
git commit -m "fix: harden appkit helper for loginwindow host"
```

### Task 5: Full verification and test-machine reinstall

**Files:**
- Modify as needed: `docs/runbooks/zh-cn-demo-guide.md`

**Step 1: Run full verification**

Run:

```bash
swift test
bash scripts/tests/plugin_passthrough_smoke.sh
bash scripts/tests/plugin_logging_smoke.sh
bash scripts/tests/install_root_smoke.sh
bash scripts/tests/install_dry_run_smoke.sh
bash scripts/tests/uninstall_root_smoke.sh
bash scripts/tests/plugin_bundle_smoke.sh
```

Expected: all commands exit `0`.

**Step 2: Reinstall on the test machine**

Use SSH to:
- pull latest `feature/option-b-demo`
- run `sudo ./scripts/install-jamf-style-demo.sh --root / --enable-authdb`
- rewrite live `system.login.console`
- verify installed paths and timestamps

**Step 3: Update operator doc**

Document the new installed helper path:
- `/Library/Application Support/DemoSSO/bin/DemoLoginShell.app`

**Step 4: Commit**

```bash
git add docs/runbooks/zh-cn-demo-guide.md
git commit -m "docs: update guide for app-bundled login shell"
```
