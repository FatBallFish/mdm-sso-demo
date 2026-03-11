# Pre-Login Button Demo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the AppKit pre-login text-entry form with a button-only demo panel that can deterministically allow, deny, or cancel the Authorization plug-in flow.

**Architecture:** Keep the plug-in launch path and result-file contract unchanged. Replace the pre-login panel state model with action-based submission, update the AppKit window to render only static copy plus buttons, and verify the three result paths with focused unit tests.

**Tech Stack:** SwiftPM, Swift, AppKit, XCTest.

---

### Task 1: Lock the new view-model contract with failing tests

**Files:**
- Modify: `Tests/DemoLoginShellSupportTests/PreLoginPanelViewModelTests.swift`
- Create: `Sources/DemoLoginShellSupport/PreLoginDemoAction.swift`
- Modify: `Sources/DemoLoginShellSupport/PreLoginPanelViewModel.swift`

**Step 1: Write the failing test**

Add tests that call `submit(action:)` with:

- `.validateSuccess` and expect `.allow(localShortName: "demouser", authSource: .fallback)`
- `.validateFailure` and expect `errorMessage == "Demo validation failed."`
- `cancel()` and expect `.userCanceled`

**Step 2: Run test to verify it fails**

Run: `swift test --filter PreLoginPanelViewModelTests`
Expected: FAIL because the view model still exposes username/password state and has no action-based API.

**Step 3: Write minimal implementation**

- add a `PreLoginDemoAction` enum
- change the validator closure signature to take a demo action
- implement `submit(action:)`
- preserve deny/allow/cancel behavior

**Step 4: Run test to verify it passes**

Run: `swift test --filter PreLoginPanelViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Tests/DemoLoginShellSupportTests/PreLoginPanelViewModelTests.swift Sources/DemoLoginShellSupport/PreLoginDemoAction.swift Sources/DemoLoginShellSupport/PreLoginPanelViewModel.swift
git commit -m "refactor: switch pre-login view model to demo actions"
```

### Task 2: Replace the AppKit text form with action buttons

**Files:**
- Modify: `Tests/DemoLoginShellSupportTests/PluginPreLoginWindowControllerTests.swift`
- Modify: `Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift`

**Step 1: Write the failing test**

Add tests that assert:

- the controller exposes three buttons for success, failure, and cancel
- the default status text is instructional
- a failure message from the view model updates the status label without closing the panel

**Step 2: Run test to verify it fails**

Run: `swift test --filter PluginPreLoginWindowControllerTests`
Expected: FAIL because the controller still owns text fields and submit logic.

**Step 3: Write minimal implementation**

- remove `NSTextField` / `NSSecureTextField`
- render static copy plus the three buttons
- wire each button to `submit(action:)` or `cancel()`
- disable buttons while submitting

**Step 4: Run test to verify it passes**

Run: `swift test --filter PluginPreLoginWindowControllerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Tests/DemoLoginShellSupportTests/PluginPreLoginWindowControllerTests.swift Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift
git commit -m "feat: replace pre-login text form with demo action buttons"
```

### Task 3: Update the shell entry point and run focused verification

**Files:**
- Modify: `Sources/DemoLoginShell/main.swift`
- Test: `Tests/DemoLoginShellSupportTests/PreLoginPanelViewModelTests.swift`
- Test: `Tests/DemoLoginShellSupportTests/PluginPreLoginWindowControllerTests.swift`

**Step 1: Write the failing test**

Rely on the controller and view-model tests above to fail until `main.swift` constructs the new validator closure.

**Step 2: Run test to verify it fails**

Run: `swift test --filter 'PreLoginPanelViewModelTests|PluginPreLoginWindowControllerTests'`
Expected: FAIL until the shell stops passing username/password closures.

**Step 3: Write minimal implementation**

- map `PreLoginDemoAction.validateSuccess` to `.allow(localShortName: "demouser", authSource: .fallback)`
- map `PreLoginDemoAction.validateFailure` to `.deny(message: "Demo validation failed.")`
- keep cancel handled by the view model

**Step 4: Run test to verify it passes**

Run: `swift test --filter 'PreLoginPanelViewModelTests|PluginPreLoginWindowControllerTests'`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoLoginShell/main.swift
git commit -m "feat: wire demo pre-login actions into login shell"
```

### Task 4: Run fresh verification before claiming completion

**Files:**
- Verify only

**Step 1: Run focused tests**

Run: `swift test --filter 'PreLoginPanelViewModelTests|PluginPreLoginWindowControllerTests|PreLoginWindowSupportTests'`
Expected: PASS

**Step 2: Run full package tests if practical**

Run: `swift test`
Expected: PASS

**Step 3: Inspect diff**

Run: `git status --short`
Expected: only intended source, test, and docs changes appear.
