# Pre-Login AppKit Shell Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the unstable SwiftUI pre-login shell with a pure AppKit shell, add plug-in helper timeout protection, and preserve the existing authentication behavior.

**Architecture:** Keep the authorization plug-in and external helper model, but move the plug-in launch mode UI to an AppKit-only controller. Reuse the existing pre-login view model and validator so only the shell presentation layer changes. Add bounded helper waiting in the plug-in so loginwindow can recover if the helper hangs.

**Tech Stack:** Swift 6, AppKit, C, Authorization Services, XCTest, shell smoke tests, Unified Logging

---

### Task 1: Add an AppKit Pre-Login Window Controller

**Files:**
- Create: `Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift`
- Create: `Tests/DemoLoginShellSupportTests/PluginPreLoginWindowControllerTests.swift`
- Modify: `Sources/DemoLoginShell/main.swift`

**Step 1: Write the failing test**

Add a test showing the AppKit controller keeps the submit button disabled until both username and password are filled.

**Step 2: Run test to verify it fails**

Run: `swift test --filter PluginPreLoginWindowControllerTests`
Expected: FAIL because the controller does not exist yet.

**Step 3: Write minimal implementation**

Build an AppKit controller with:

- `NSTextField` username
- `NSSecureTextField` password
- submit and cancel buttons
- status label
- button state synced from text changes and view model state

Wire `DemoLoginShell` plug-in mode to this controller instead of the SwiftUI pre-login view.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PluginPreLoginWindowControllerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift Tests/DemoLoginShellSupportTests/PluginPreLoginWindowControllerTests.swift Sources/DemoLoginShell/main.swift
git commit -m "fix: use appkit pre-login shell controller"
```

### Task 2: Add Plug-In Helper Timeout Protection

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginEntry.c`
- Modify: `scripts/tests/plugin_shell_helper.sh`
- Modify: `scripts/tests/plugin_passthrough_smoke.sh`

**Step 1: Write the failing test**

Extend the passthrough smoke so a helper that sleeps longer than the configured timeout causes the plug-in to allow native login instead of blocking forever.

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`
Expected: FAIL because the plug-in currently waits indefinitely for the helper to exit.

**Step 3: Write minimal implementation**

Add timeout logic to the plug-in:

- configurable with `DEMO_LOGIN_SHELL_TIMEOUT_SECONDS`
- poll child exit with `waitpid(..., WNOHANG)`
- terminate timed-out helper
- log timeout
- return `allow` fallback

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginEntry.c scripts/tests/plugin_shell_helper.sh scripts/tests/plugin_passthrough_smoke.sh
git commit -m "fix: bound pre-login shell wait time"
```

### Task 3: Add Pre-Login Shell Logging and Docs

**Files:**
- Modify: `Sources/DemoLoginShell/main.swift`
- Modify: `Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift`
- Modify: `docs/runbooks/zh-cn-demo-guide.md`

**Step 1: Write the failing test**

Update the logging smoke so it asserts the source contains:

- shell launch mode log
- AppKit pre-login window shown log
- shell completion log

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: FAIL because the new shell log strings do not exist yet.

**Step 3: Write minimal implementation**

Add focused logs around:

- plug-in launch mode selected
- AppKit pre-login window shown
- submit / cancel action
- result file write

Update the Chinese runbook with the expected live authdb ordering and the new log markers.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginShell/main.swift Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift docs/runbooks/zh-cn-demo-guide.md
git commit -m "docs: add appkit pre-login shell logging guide"
```

### Task 4: Run Full Verification

**Files:**
- Modify as needed from previous tasks

**Step 1: Run verification**

Run:

```bash
swift test
bash scripts/tests/plugin_passthrough_smoke.sh
bash scripts/tests/plugin_logging_smoke.sh
bash scripts/tests/authdb_transform_smoke.sh
bash scripts/tests/plugin_bundle_smoke.sh
```

**Step 2: Fix regressions if any**

Make only the smallest follow-up changes required.

**Step 3: Re-run verification**

Run the same commands again and confirm all pass.

**Step 4: Commit**

```bash
git add -A
git commit -m "fix: stabilize pre-login shell in appkit mode"
```
