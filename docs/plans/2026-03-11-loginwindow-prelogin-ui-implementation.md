# LoginWindow Pre-Login UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a custom pre-login SSO UI that appears before the native macOS login prompt, prefers local HTTP IdP validation, falls back to fixed demo credentials, and only then continues the native login chain for existing local accounts.

**Architecture:** Keep the Authorization Services entry point in C, move UI and auth behavior into Swift support code, and reuse existing shared models plus the current demo IdP client. Update authdb transform logic so the plug-in executes before `loginwindow:login`, not after it. Limit the system-login milestone to already-existing local accounts for stability.

**Tech Stack:** Swift 6, C, Authorization Services, AppKit, Foundation networking, XCTest, shell smoke tests, Unified Logging

---

### Task 1: Add Shared Pre-Login Decision Models

**Files:**
- Modify: `Sources/DemoLoginPluginSupport/LoginBridge.swift`
- Create: `Sources/DemoLoginPluginSupport/PreLoginAuthResult.swift`
- Test: `Tests/DemoLoginPluginSupportTests/LoginPluginBridgeTests.swift`

**Step 1: Write the failing test**

Add tests covering:

- HTTP success maps to `allow`
- fallback success maps to `allow`
- unmapped local account maps to `deny`
- user cancel maps to `deny` or `userCanceled`, whichever shape is chosen

**Step 2: Run test to verify it fails**

Run: `swift test --filter LoginPluginBridgeTests`

Expected: FAIL because the new result shapes do not exist yet.

**Step 3: Write minimal implementation**

Create a small result model describing:

- `allow(localShortName: String, authSource: http|fallback)`
- `deny(message: String)`
- `userCanceled`

Update the bridge so the plug-in support layer and C layer have one stable contract.

**Step 4: Run test to verify it passes**

Run: `swift test --filter LoginPluginBridgeTests`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginSupport/LoginBridge.swift Sources/DemoLoginPluginSupport/PreLoginAuthResult.swift Tests/DemoLoginPluginSupportTests/LoginPluginBridgeTests.swift
git commit -m "feat: add pre-login auth result models"
```

### Task 2: Build HTTP-First / Fallback-Second Auth Coordinator

**Files:**
- Create: `Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift`
- Modify: `Sources/DemoLoginShellSupport/DemoIDPHTTPClient.swift`
- Modify: `Sources/DemoShared/DemoAuthenticator.swift`
- Test: `Tests/DemoLoginPluginSupportTests/PluginCredentialValidatorTests.swift`

**Step 1: Write the failing test**

Create tests for:

- health succeeds and login succeeds -> result source `http`
- health fails -> fallback credentials used
- health succeeds but login transport fails -> fallback credentials used
- both HTTP and fallback fail -> deny

**Step 2: Run test to verify it fails**

Run: `swift test --filter PluginCredentialValidatorTests`

Expected: FAIL because the coordinator does not exist yet.

**Step 3: Write minimal implementation**

Create a coordinator that:

- checks `/api/health`
- tries `/api/login`
- catches transport failures
- reuses fixed credential validation from shared demo accounts

Do not add account creation here.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PluginCredentialValidatorTests`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift Sources/DemoLoginShellSupport/DemoIDPHTTPClient.swift Sources/DemoShared/DemoAuthenticator.swift Tests/DemoLoginPluginSupportTests/PluginCredentialValidatorTests.swift
git commit -m "feat: add plugin http-first fallback auth"
```

### Task 3: Build the Plug-In Pre-Login AppKit Panel

**Files:**
- Create: `Sources/DemoLoginPluginSupport/PluginLoginPanelController.swift`
- Create: `Sources/DemoLoginPluginSupport/PluginLoginPanelView.swift`
- Create: `Sources/DemoLoginPluginSupport/PluginLoginPanelViewModel.swift`
- Test: `Tests/DemoLoginPluginSupportTests/PluginLoginPanelViewModelTests.swift`

**Step 1: Write the failing test**

Add tests showing:

- submitting valid credentials moves to success state
- invalid credentials stays on the panel with error text
- cancel produces canceled state

**Step 2: Run test to verify it fails**

Run: `swift test --filter PluginLoginPanelViewModelTests`

Expected: FAIL because the view model does not exist.

**Step 3: Write minimal implementation**

Implement a minimal AppKit-backed panel with:

- username
- password
- sign-in
- cancel
- status text

Keep styling simple and robust for loginwindow host execution.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PluginLoginPanelViewModelTests`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginSupport/PluginLoginPanelController.swift Sources/DemoLoginPluginSupport/PluginLoginPanelView.swift Sources/DemoLoginPluginSupport/PluginLoginPanelViewModel.swift Tests/DemoLoginPluginSupportTests/PluginLoginPanelViewModelTests.swift
git commit -m "feat: add pre-login plugin panel ui"
```

### Task 4: Wire the C Plug-In to Block on UI Result

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginEntry.c`
- Create: `Sources/DemoLoginPluginC/include/DemoLoginPluginInterop.h`
- Create: `Sources/DemoLoginPluginSupport/PluginMechanismRunner.swift`
- Test: `scripts/tests/plugin_passthrough_harness.c`
- Test: `scripts/tests/plugin_passthrough_smoke.sh`

**Step 1: Write the failing test**

Extend the harness/smoke coverage to prove:

- invoke no longer blindly allows
- valid credentials can produce allow
- invalid credentials can produce deny

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`

Expected: FAIL because the current plug-in always allows.

**Step 3: Write minimal implementation**

Add a Swift-callable runner invoked from C that:

- shows the pre-login panel
- waits synchronously for user result
- returns allow / deny / cancel

Update `MechanismInvoke` to use that result instead of unconditional allow.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_passthrough_smoke.sh`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginEntry.c Sources/DemoLoginPluginC/include/DemoLoginPluginInterop.h Sources/DemoLoginPluginSupport/PluginMechanismRunner.swift scripts/tests/plugin_passthrough_harness.c scripts/tests/plugin_passthrough_smoke.sh
git commit -m "feat: connect plugin invoke to pre-login ui"
```

### Task 5: Reorder Authdb so the Plug-In Runs Before Native Login

**Files:**
- Modify: `scripts/configure-loginwindow-authdb.sh`
- Modify: `scripts/tests/authdb_transform_smoke.sh`
- Modify: `docs/runbooks/zh-cn-demo-guide.md`
- Modify: `docs/runbooks/lab-setup.md`

**Step 1: Write the failing test**

Update the smoke test to assert the plug-in mechanism appears before `loginwindow:login`.

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/authdb_transform_smoke.sh`

Expected: FAIL because the script currently inserts the mechanism after `loginwindow:login`.

**Step 3: Write minimal implementation**

Change the transform script so the mechanism is inserted before `loginwindow:login`.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/authdb_transform_smoke.sh`

Expected: PASS

**Step 5: Commit**

```bash
git add scripts/configure-loginwindow-authdb.sh scripts/tests/authdb_transform_smoke.sh docs/runbooks/zh-cn-demo-guide.md docs/runbooks/lab-setup.md
git commit -m "feat: run plugin before native login"
```

### Task 6: Add Logging for HTTP vs Fallback Behavior

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginEntry.c`
- Modify: `Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift`
- Modify: `docs/runbooks/zh-cn-demo-guide.md`
- Test: `scripts/tests/plugin_logging_smoke.sh`

**Step 1: Write the failing test**

Extend the logging smoke to assert the binary contains log messages for:

- panel shown
- HTTP auth path
- fallback auth path
- final allow / deny

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_logging_smoke.sh`

Expected: FAIL because the new log strings are absent.

**Step 3: Write minimal implementation**

Add unified log statements that distinguish:

- `auth_source=http`
- `auth_source=fallback`
- local mapping success / failure
- user cancel

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_logging_smoke.sh`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginEntry.c Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift docs/runbooks/zh-cn-demo-guide.md scripts/tests/plugin_logging_smoke.sh
git commit -m "feat: add pre-login plugin auth source logging"
```

### Task 7: Validate End-to-End LoginWindow Demo Flow

**Files:**
- Modify: `docs/runbooks/manual-test-matrix.md`
- Modify: `docs/runbooks/zh-cn-demo-guide.md`

**Step 1: Write the validation checklist**

Document manual test cases for:

- custom UI shown before native login
- HTTP IdP path succeeds
- fallback path succeeds when local IdP is down
- invalid credentials stay on custom UI
- successful login enters the desktop for an existing local account

**Step 2: Run automated checks**

Run:

```bash
swift test
bash scripts/tests/login_broker_smoke.sh
bash scripts/tests/plugin_passthrough_smoke.sh
bash scripts/tests/plugin_logging_smoke.sh
bash scripts/tests/authdb_transform_smoke.sh
```

Expected: all PASS

**Step 3: Run real-machine validation**

Run the documented system-login validation flow on a test machine.

**Step 4: Commit**

```bash
git add docs/runbooks/manual-test-matrix.md docs/runbooks/zh-cn-demo-guide.md
git commit -m "docs: add pre-login ui validation flow"
```
