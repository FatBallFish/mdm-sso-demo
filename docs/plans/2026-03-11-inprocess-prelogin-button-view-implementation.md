# In-Process Pre-Login Button View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current text-entry `SecurityAgent` plug-in view with a deterministic, button-only in-process pre-login view that can allow, deny, or cancel without launching the external helper UI.

**Architecture:** Keep the Authorization plug-in mechanism entry points unchanged, but move the first visible interaction back into `DemoAuthorizationLoginView`. Remove text fields, network validation, and seeded account lookup from the in-process view. Use three custom buttons to drive the allow/deny/cancel mechanism results directly.

**Tech Stack:** Objective-C, AppKit, SecurityInterface, bash smoke tests, SwiftPM package tests.

---

### Task 1: Lock the new plug-in view contract with failing smoke tests

**Files:**
- Modify: `scripts/tests/plugin_logging_smoke.sh`
- Create: `scripts/tests/plugin_inprocess_button_view_smoke.sh`
- Modify: `Sources/DemoLoginPluginC/PluginLoginView.m`

**Step 1: Write the failing test**

Add smoke assertions that `PluginLoginView.m`:

- contains `Validate Success`
- contains `Validate Failure`
- contains `Back To macOS Login`
- does not contain editable `NSTextField` / `NSSecureTextField` controls for username/password
- contains action-level log markers for success/failure/cancel

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_inprocess_button_view_smoke.sh`
Expected: FAIL because the source still declares username/password text fields and old authentication methods.

**Step 3: Write minimal implementation**

Change the in-process plug-in view source until the smoke assertions match the new shape.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_inprocess_button_view_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/tests/plugin_inprocess_button_view_smoke.sh scripts/tests/plugin_logging_smoke.sh Sources/DemoLoginPluginC/PluginLoginView.m
git commit -m "test: lock in-process pre-login button view contract"
```

### Task 2: Implement the in-process three-button view

**Files:**
- Modify: `Sources/DemoLoginPluginC/PluginLoginView.m`

**Step 1: Write the failing test**

Use the smoke test above as the active failing test and ensure it fails specifically because the old view still uses text input and network/fallback validation methods.

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_inprocess_button_view_smoke.sh`
Expected: FAIL

**Step 3: Write minimal implementation**

- remove username/password fields
- remove HTTP health/login flow
- remove seeded account lookup helpers from the in-process view
- add three custom buttons
- wire success to `DemoPluginApplyCredentials(..., "demouser", "DemoPass123!")`
- wire failure to update the status label and keep the view active
- wire cancel to `kAuthorizationResultUserCanceled`

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_inprocess_button_view_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginPluginC/PluginLoginView.m
git commit -m "feat: move pre-login demo actions into plugin view"
```

### Task 3: Keep package and bundle verification green

**Files:**
- Modify: `scripts/tests/plugin_logging_smoke.sh`
- Test: `scripts/tests/plugin_bundle_smoke.sh`
- Test: `scripts/tests/plugin_inprocess_button_view_smoke.sh`
- Test: `Tests/DemoLoginShellSupportTests/*`

**Step 1: Write the failing test**

Update the logging smoke to stop asserting the external helper as the primary UI proof point and to assert the new in-process action markers.

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: FAIL because the source still only contains helper-oriented assertions.

**Step 3: Write minimal implementation**

Adjust the smoke coverage so it reflects the new primary path while preserving helper-path coverage where still relevant for fallback instrumentation.

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/plugin_logging_smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/tests/plugin_logging_smoke.sh
git commit -m "test: update plugin logging smoke for in-process view"
```

### Task 4: Full verification before remote reinstall

**Files:**
- Verify only

**Step 1: Run focused smoke tests**

Run:

```bash
bash scripts/tests/plugin_inprocess_button_view_smoke.sh
bash scripts/tests/plugin_logging_smoke.sh
bash scripts/tests/plugin_bundle_smoke.sh
```

Expected: PASS

**Step 2: Run package tests**

Run: `swift test`
Expected: PASS

**Step 3: Check worktree**

Run: `git status --short`
Expected: only intended source, docs, and test files are modified.

**Step 4: Push and reinstall on remote test machine**

Run:

```bash
git push origin feature/option-b-demo
```

Then on the remote machine:

```bash
sudo ./scripts/install-jamf-style-demo.sh --root / --enable-authdb
sudo sh -c "security authorizationdb write system.login.console < '/Library/Application Support/DemoSSO/authdb/system.login.console.demo.plist'"
```
