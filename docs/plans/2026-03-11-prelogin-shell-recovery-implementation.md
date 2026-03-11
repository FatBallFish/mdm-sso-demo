# Pre-Login Shell Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore a working Jamf-style pre-login demo by reverting the plug-in to spawn the native login shell, making the shell window visible before user login, and preserving a safe fallback to native macOS login when the helper path fails.

**Architecture:** Move the live UI path out of the Authorization plug-in host and back into the standalone `DemoLoginShell` process. Keep the plug-in responsible for spawning the shell, reading a result plist, applying credentials to the authorization engine, and allowing native login if the shell path is unavailable so the test machine is never bricked.

**Tech Stack:** Swift 6, AppKit, SwiftUI, C, Authorization Services, shell smoke tests, XCTest

---

### Task 1: Make Pre-Login Shell Window Configuration Testable

**Files:**
- Create: `Tests/DemoLoginShellSupportTests/PreLoginWindowSupportTests.swift`
- Create: `Sources/DemoLoginShellSupport/PreLoginWindowSupport.swift`
- Modify: `Sources/DemoLoginShell/main.swift`

**Step 1: Write the failing test**

```swift
import AppKit
import DemoLoginShellSupport
import XCTest

final class PreLoginWindowSupportTests: XCTestCase {
    func test_prepareForPreLoginDisplay_enables_visibility_before_login() {
        let window = NSWindow()

        configurePreLoginWindow(window)

        XCTAssertTrue(window.canBecomeVisibleWithoutLogin)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter PreLoginWindowSupportTests/test_prepareForPreLoginDisplay_enables_visibility_before_login`
Expected: FAIL because `configurePreLoginWindow` does not exist yet.

**Step 3: Write minimal implementation**

Add a small helper in `DemoLoginShellSupport` that sets:

- `canBecomeVisibleWithoutLogin = true`
- stable pre-login collection behavior
- simple non-closable window presentation defaults used by the shell

Call it from `DemoLoginShell` before the window is shown.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PreLoginWindowSupportTests/test_prepareForPreLoginDisplay_enables_visibility_before_login`
Expected: PASS

**Step 5: Commit**

```bash
git add Tests/DemoLoginShellSupportTests/PreLoginWindowSupportTests.swift Sources/DemoLoginShellSupport/PreLoginWindowSupport.swift Sources/DemoLoginShell/main.swift
git commit -m "fix: make pre-login shell window visible before login"
```

### Task 2: Revert Plug-In to External Shell Flow

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginEntry.c`
- Modify: `Sources/DemoLoginPluginC/include/DemoLoginPlugin.h`
- Modify: `scripts/tests/plugin_passthrough_smoke.sh`
- Add: `scripts/tests/plugin_shell_helper.sh`
- Modify: `scripts/tests/plugin_logging_smoke.sh`

**Step 1: Write the failing test**

Update the smoke test so it:

- points `DEMO_LOGIN_SHELL_PATH` at a deterministic helper
- verifies `allow` credentials come back from the helper plist
- verifies `deny`
- verifies helper failure falls back to native login with `allow`

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`
Expected: FAIL because the plug-in still tries to create `SFAuthorizationPluginView` instead of spawning the shell helper.

**Step 3: Write minimal implementation**

Restore the shell path in `PluginEntry.c`:

- create a temp result file
- `posix_spawn` the login shell with `--plugin-result-file`
- wait for shell exit
- parse the plist result
- apply local username/password context on `allow`
- if helper launch/read fails, log once and return `kAuthorizationResultAllow`

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginEntry.c Sources/DemoLoginPluginC/include/DemoLoginPlugin.h scripts/tests/plugin_passthrough_smoke.sh scripts/tests/plugin_shell_helper.sh scripts/tests/plugin_logging_smoke.sh
git commit -m "fix: restore plugin pre-login shell flow"
```

### Task 3: Restore Authdb Ordering for Pre-Login Takeover

**Files:**
- Modify: `scripts/configure-loginwindow-authdb.sh`
- Modify: `scripts/tests/authdb_transform_smoke.sh`
- Modify: `docs/runbooks/lab-setup.md`
- Modify: `docs/runbooks/zh-cn-demo-guide.md`

**Step 1: Write the failing test**

Assert the generated mechanism order is:

- `builtin:policy-banner`
- `DemoLoginPlugin:login`
- `loginwindow:login`

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/authdb_transform_smoke.sh`
Expected: FAIL because the script currently inserts the plug-in after `loginwindow:login`.

**Step 3: Write minimal implementation**

Insert `DemoLoginPlugin:login` before `loginwindow:login`.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/authdb_transform_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/configure-loginwindow-authdb.sh scripts/tests/authdb_transform_smoke.sh docs/runbooks/lab-setup.md docs/runbooks/zh-cn-demo-guide.md
git commit -m "fix: run plugin before native login for shell flow"
```

### Task 4: Verify Recovery End-to-End

**Files:**
- Modify as needed from previous tasks

**Step 1: Run focused verification**

Run:

```bash
swift test --filter PreLoginWindowSupportTests
bash scripts/tests/plugin_passthrough_smoke.sh
bash scripts/tests/plugin_logging_smoke.sh
bash scripts/tests/authdb_transform_smoke.sh
swift test
```

**Step 2: Fix any regressions**

Make only minimal follow-up changes required to keep the suite green.

**Step 3: Re-run verification**

Run the same commands again and confirm all pass.

**Step 4: Commit**

```bash
git add -A
git commit -m "fix: recover pre-login shell based loginwindow demo"
```
