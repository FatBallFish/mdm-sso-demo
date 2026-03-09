# Jamf-Style macOS LoginWindow SSO Demo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Jamf Connect-style macOS LoginWindow SSO demo that can intercept login, validate against a fixed demo IdP, bind or create a local account, support offline login, keep local password in sync, and provide a safe uninstall path.

**Architecture:** Use a mixed macOS workspace. The login interception component is an Authorization Services plug-in written in Objective-C/C for compatibility with the login mechanism interface. Business logic, state storage, status UI, and privileged account sync services are implemented in Swift. A small local demo IdP service is implemented as a standalone Swift executable to avoid third-party runtime dependencies.

**Tech Stack:** Xcode workspace, Swift 6, Objective-C, C, AppKit, SwiftUI, LaunchDaemon, LaunchAgent, XCTest, shell scripts, local property list storage

---

## Repository Layout

The implementation should create this structure:

```text
Package.swift
Sources/
  DemoShared/
  DemoIDPServer/
  DemoTools/
Tests/
  DemoSharedTests/
macos/
  DemoSSO.xcodeproj/
  LoginPlugin/
  LoginUI/
  AccountSyncDaemon/
  StatusAgent/
  PrivilegedHelper/
configs/
  demo-idp.json
launchd/
  com.demo.sso.accountsync.plist
  com.demo.sso.statusagent.plist
scripts/
  install-jamf-style-demo.sh
  uninstall-jamf-style-demo.sh
  restore-native-loginwindow.sh
docs/
  runbooks/
    lab-setup.md
    manual-test-matrix.md
```

## Task 1: Bootstrap the Mixed Swift and Xcode Workspace

**Files:**
- Create: `Package.swift`
- Create: `Sources/DemoShared/Models.swift`
- Create: `Sources/DemoShared/Config.swift`
- Create: `Sources/DemoShared/MappingStore.swift`
- Create: `Tests/DemoSharedTests/MappingStoreTests.swift`
- Create: `macos/DemoSSO.xcodeproj/project.pbxproj`
- Create: `docs/runbooks/lab-setup.md`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import DemoShared

final class MappingStoreTests: XCTestCase {
    func test_round_trip_mapping_persists_subject_and_local_user() throws {
        let store = MappingStore(baseURL: FileManager.default.temporaryDirectory)
        let record = AccountMapping(
            ssoSubject: "demo.user",
            localShortName: "demouser",
            lastOnlineAuthAt: Date(timeIntervalSince1970: 1000),
            offlineGraceExpiry: Date(timeIntervalSince1970: 2000),
            lastTokenRefreshAt: nil
        )

        try store.save(record)
        let loaded = try store.load(subject: "demo.user")

        XCTAssertEqual(loaded?.localShortName, "demouser")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter MappingStoreTests/test_round_trip_mapping_persists_subject_and_local_user`

Expected: FAIL because `Package.swift`, `DemoShared`, and `MappingStore` do not exist yet.

**Step 3: Write minimal implementation**

```swift
public struct AccountMapping: Codable, Equatable {
    public let ssoSubject: String
    public let localShortName: String
    public let lastOnlineAuthAt: Date
    public let offlineGraceExpiry: Date
    public let lastTokenRefreshAt: Date?
}

public final class MappingStore {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func save(_ record: AccountMapping) throws {
        let url = baseURL.appendingPathComponent("\(record.ssoSubject).json")
        let data = try JSONEncoder().encode(record)
        try data.write(to: url)
    }

    public func load(subject: String) throws -> AccountMapping? {
        let url = baseURL.appendingPathComponent("\(subject).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AccountMapping.self, from: data)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter MappingStoreTests/test_round_trip_mapping_persists_subject_and_local_user`

Expected: PASS

**Step 5: Commit**

```bash
git add Package.swift Sources/DemoShared Tests/DemoSharedTests docs/runbooks/lab-setup.md macos/DemoSSO.xcodeproj
git commit -m "chore: bootstrap jamf-style demo workspace"
```

## Task 2: Build the Demo IdP Service with Fixed Credentials

**Files:**
- Create: `Sources/DemoIDPServer/main.swift`
- Create: `Sources/DemoShared/TokenModels.swift`
- Create: `Tests/DemoSharedTests/TokenCodecTests.swift`
- Create: `configs/demo-idp.json`
- Modify: `Package.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import DemoShared

final class TokenCodecTests: XCTestCase {
    func test_access_token_expiry_is_encoded_in_response() throws {
        let response = DemoTokenResponse(
            accessToken: "a",
            refreshToken: "r",
            expiresInSeconds: 3600,
            subject: "demo.user"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(DemoTokenResponse.self, from: data)

        XCTAssertEqual(decoded.expiresInSeconds, 3600)
        XCTAssertEqual(decoded.subject, "demo.user")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter TokenCodecTests/test_access_token_expiry_is_encoded_in_response`

Expected: FAIL because `DemoTokenResponse` does not exist yet.

**Step 3: Write minimal implementation**

```swift
public struct DemoTokenResponse: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresInSeconds: Int
    public let subject: String
}
```

Create the demo server with these routes:

- `POST /api/login`
- `POST /api/refresh`
- `GET /api/health`

Minimal login logic:

```swift
if request.username == "demo.user" && request.password == "DemoPass123!" {
    return DemoTokenResponse(
        accessToken: UUID().uuidString,
        refreshToken: UUID().uuidString,
        expiresInSeconds: 3600,
        subject: "demo.user"
    )
}
```

**Step 4: Run test and build to verify**

Run: `swift test --filter TokenCodecTests/test_access_token_expiry_is_encoded_in_response`

Expected: PASS

Run: `swift build --product DemoIDPServer`

Expected: PASS

**Step 5: Commit**

```bash
git add Package.swift Sources/DemoIDPServer Sources/DemoShared/TokenModels.swift Tests/DemoSharedTests/TokenCodecTests.swift configs/demo-idp.json
git commit -m "feat: add fixed-credential demo idp service"
```

## Task 3: Implement Shared Login Policy and Offline Grace Rules

**Files:**
- Create: `Sources/DemoShared/LoginPolicy.swift`
- Create: `Tests/DemoSharedTests/LoginPolicyTests.swift`
- Modify: `Sources/DemoShared/Models.swift`
- Modify: `Sources/DemoShared/MappingStore.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import DemoShared

final class LoginPolicyTests: XCTestCase {
    func test_offline_login_is_denied_after_grace_expiry() {
        let policy = LoginPolicy(now: {
            Date(timeIntervalSince1970: 10_000)
        })

        let record = AccountMapping(
            ssoSubject: "demo.user",
            localShortName: "demouser",
            lastOnlineAuthAt: Date(timeIntervalSince1970: 1000),
            offlineGraceExpiry: Date(timeIntervalSince1970: 9999),
            lastTokenRefreshAt: nil
        )

        XCTAssertFalse(policy.isOfflineLoginAllowed(record))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter LoginPolicyTests/test_offline_login_is_denied_after_grace_expiry`

Expected: FAIL because `LoginPolicy` does not exist.

**Step 3: Write minimal implementation**

```swift
public struct LoginPolicy {
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public func isOfflineLoginAllowed(_ record: AccountMapping) -> Bool {
        now() < record.offlineGraceExpiry
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter LoginPolicyTests/test_offline_login_is_denied_after_grace_expiry`

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/DemoShared/LoginPolicy.swift Tests/DemoSharedTests/LoginPolicyTests.swift Sources/DemoShared/Models.swift Sources/DemoShared/MappingStore.swift
git commit -m "feat: add offline login policy primitives"
```

## Task 4: Build the Account Sync Daemon for Binding, Creation, and Password Sync

**Files:**
- Create: `macos/AccountSyncDaemon/AccountSyncDaemon.swift`
- Create: `macos/AccountSyncDaemon/DirectoryService.swift`
- Create: `macos/AccountSyncDaemon/PasswordSyncCoordinator.swift`
- Create: `macos/AccountSyncDaemon/DaemonMain.swift`
- Create: `macos/AccountSyncDaemonTests/PasswordSyncCoordinatorTests.swift`
- Create: `launchd/com.demo.sso.accountsync.plist`
- Modify: `macos/DemoSSO.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import AccountSyncDaemon

final class PasswordSyncCoordinatorTests: XCTestCase {
    func test_sync_request_marks_local_password_for_rotation_when_hashes_differ() {
        let coordinator = PasswordSyncCoordinator()
        let action = coordinator.reconcile(localPasswordFingerprint: "old", remotePasswordFingerprint: "new")

        XCTAssertEqual(action, .rotateLocalPassword)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme AccountSyncDaemon -destination 'platform=macOS'`

Expected: FAIL because the target and coordinator do not exist yet.

**Step 3: Write minimal implementation**

```swift
enum PasswordSyncAction: Equatable {
    case noop
    case rotateLocalPassword
}

struct PasswordSyncCoordinator {
    func reconcile(localPasswordFingerprint: String, remotePasswordFingerprint: String) -> PasswordSyncAction {
        localPasswordFingerprint == remotePasswordFingerprint ? .noop : .rotateLocalPassword
    }
}
```

Daemon responsibilities:

- maintain account mapping files under `/Library/Application Support/DemoSSO/`
- create local users
- bind SSO subject to a local short name
- rotate the local password after successful online auth
- expose a small XPC or file-based request interface to the login plug-in and status agent

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme AccountSyncDaemon -destination 'platform=macOS'`

Expected: PASS

**Step 5: Commit**

```bash
git add macos/AccountSyncDaemon macos/AccountSyncDaemonTests launchd/com.demo.sso.accountsync.plist macos/DemoSSO.xcodeproj/project.pbxproj
git commit -m "feat: add account sync daemon skeleton"
```

## Task 5: Build the Status Agent for Token Refresh and Reauth State

**Files:**
- Create: `macos/StatusAgent/StatusAgentApp.swift`
- Create: `macos/StatusAgent/TokenRefreshScheduler.swift`
- Create: `macos/StatusAgent/TokenClient.swift`
- Create: `macos/StatusAgentTests/TokenRefreshSchedulerTests.swift`
- Create: `launchd/com.demo.sso.statusagent.plist`
- Modify: `macos/DemoSSO.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import StatusAgent

final class TokenRefreshSchedulerTests: XCTestCase {
    func test_refresh_is_requested_when_token_expires_within_ten_minutes() {
        let scheduler = TokenRefreshScheduler(refreshLeadTime: 600)
        let shouldRefresh = scheduler.shouldRefresh(now: 1000, expiry: 1500)

        XCTAssertTrue(shouldRefresh)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme StatusAgent -destination 'platform=macOS'`

Expected: FAIL because the target and scheduler do not exist yet.

**Step 3: Write minimal implementation**

```swift
struct TokenRefreshScheduler {
    let refreshLeadTime: TimeInterval

    func shouldRefresh(now: TimeInterval, expiry: TimeInterval) -> Bool {
        expiry - now <= refreshLeadTime
    }
}
```

Status agent responsibilities:

- run every 15 minutes while a user session exists
- refresh tokens with the demo IdP
- persist token metadata locally
- mark the account for interactive reauth when refresh fails
- surface current state in a lightweight menu bar or diagnostics window

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme StatusAgent -destination 'platform=macOS'`

Expected: PASS

**Step 5: Commit**

```bash
git add macos/StatusAgent macos/StatusAgentTests launchd/com.demo.sso.statusagent.plist macos/DemoSSO.xcodeproj/project.pbxproj
git commit -m "feat: add token refresh status agent"
```

## Task 6: Build the Native Login UI

**Files:**
- Create: `macos/LoginUI/LoginWindowController.swift`
- Create: `macos/LoginUI/LoginViewModel.swift`
- Create: `macos/LoginUI/AccountBindingView.swift`
- Create: `macos/LoginUI/Assets.xcassets/Contents.json`
- Create: `macos/LoginUITests/LoginViewModelTests.swift`
- Modify: `macos/DemoSSO.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import LoginUI

final class LoginViewModelTests: XCTestCase {
    func test_account_binding_prompt_is_shown_for_unmapped_subject() {
        let viewModel = LoginViewModel()
        viewModel.handleLoginResult(.needsAccountBinding(subject: "demo.user"))

        XCTAssertEqual(viewModel.screen, .accountBinding)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginUI -destination 'platform=macOS'`

Expected: FAIL because the target and view model do not exist yet.

**Step 3: Write minimal implementation**

```swift
enum LoginScreen: Equatable {
    case credentialEntry
    case accountBinding
    case success
    case error(String)
}

enum LoginResult {
    case success
    case needsAccountBinding(subject: String)
    case failure(String)
}

final class LoginViewModel: ObservableObject {
    @Published var screen: LoginScreen = .credentialEntry

    func handleLoginResult(_ result: LoginResult) {
        switch result {
        case .success:
            screen = .success
        case .needsAccountBinding:
            screen = .accountBinding
        case let .failure(message):
            screen = .error(message)
        }
    }
}
```

UI screens to implement:

- credential entry
- existing account binding picker
- new local account creation form
- offline login message
- uninstall or restore instructions for admins

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginUI -destination 'platform=macOS'`

Expected: PASS

**Step 5: Commit**

```bash
git add macos/LoginUI macos/LoginUITests macos/DemoSSO.xcodeproj/project.pbxproj
git commit -m "feat: add native login ui flow"
```

## Task 7: Implement the Login Plug-in and LoginWindow Handoff

**Files:**
- Create: `macos/LoginPlugin/PluginEntry.c`
- Create: `macos/LoginPlugin/DemoAuthorizationPlugin.h`
- Create: `macos/LoginPlugin/DemoAuthorizationPlugin.m`
- Create: `macos/LoginPlugin/LoginBridge.swift`
- Create: `macos/LoginPluginTests/LoginBridgeTests.swift`
- Modify: `macos/DemoSSO.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import LoginPlugin

final class LoginBridgeTests: XCTestCase {
    func test_successful_idp_result_maps_to_allow_login() {
        let bridge = LoginBridge()
        XCTAssertEqual(bridge.map(result: .success), .allow)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginPlugin -destination 'platform=macOS'`

Expected: FAIL because the bridge and plug-in target do not exist yet.

**Step 3: Write minimal implementation**

```swift
enum BridgeLoginResult {
    case success
    case failure
}

enum MechanismDisposition: Equatable {
    case allow
    case deny
}

struct LoginBridge {
    func map(result: BridgeLoginResult) -> MechanismDisposition {
        result == .success ? .allow : .deny
    }
}
```

Plug-in responsibilities:

- expose `AuthorizationPluginCreate`
- create the login mechanism instance
- invoke the native login UI
- pass successful auth results to the daemon
- continue or deny the login mechanism result

Do not attempt phase-1 FileVault unlock here. This milestone only proves loginwindow interception plus local account continuation.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginPlugin -destination 'platform=macOS'`

Expected: PASS

**Step 5: Commit**

```bash
git add macos/LoginPlugin macos/LoginPluginTests macos/DemoSSO.xcodeproj/project.pbxproj
git commit -m "feat: add loginwindow plugin bridge"
```

## Task 8: Add Install, Restore, and Uninstall Automation

**Files:**
- Create: `scripts/install-jamf-style-demo.sh`
- Create: `scripts/uninstall-jamf-style-demo.sh`
- Create: `scripts/restore-native-loginwindow.sh`
- Create: `docs/runbooks/manual-test-matrix.md`
- Modify: `docs/runbooks/lab-setup.md`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

./scripts/install-jamf-style-demo.sh --dry-run | grep -q "SecurityAgentPlugins"
```

Save as `scripts/tests/install_dry_run_smoke.sh`

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/install_dry_run_smoke.sh`

Expected: FAIL because the install script does not exist yet.

**Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "Would copy LoginPlugin bundle into /Library/Security/SecurityAgentPlugins/"
  echo "Would load launchd jobs from ./launchd/"
  echo "Would enable custom loginwindow auth chain"
  exit 0
fi
```

Install automation must handle:

- copying plug-in bundle
- installing daemon and agent
- writing config under `/Library/Application Support/DemoSSO/`
- loading launchd jobs
- enabling the custom login chain

Uninstall must:

- restore native loginwindow behavior first
- unload and remove daemon and agent
- remove plug-in and app artifacts
- keep or purge mappings based on a flag

**Step 4: Run test to verify it passes**

Run: `bash scripts/tests/install_dry_run_smoke.sh`

Expected: PASS

**Step 5: Commit**

```bash
git add scripts docs/runbooks/manual-test-matrix.md docs/runbooks/lab-setup.md
git commit -m "feat: add install and uninstall automation"
```

## Task 9: Add End-to-End Integration Stubs and Verification Docs

**Files:**
- Create: `Tests/DemoSharedTests/IntegrationContractTests.swift`
- Modify: `docs/runbooks/manual-test-matrix.md`
- Modify: `docs/runbooks/lab-setup.md`
- Create: `docs/runbooks/known-limitations.md`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import DemoShared

final class IntegrationContractTests: XCTestCase {
    func test_default_offline_grace_period_is_seven_days() {
        XCTAssertEqual(DemoConfiguration.defaultOfflineGraceDays, 7)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter IntegrationContractTests/test_default_offline_grace_period_is_seven_days`

Expected: FAIL because the configuration constant does not exist yet.

**Step 3: Write minimal implementation**

```swift
public enum DemoConfiguration {
    public static let defaultOfflineGraceDays = 7
}
```

Document these manual scenarios:

- first online login with new local account creation
- first online login with existing local account binding
- offline login within grace
- offline login after grace expiry
- token refresh success
- token refresh failure leading to reauth
- password drift followed by local sync
- uninstall and restore of native loginwindow

**Step 4: Run test to verify it passes**

Run: `swift test --filter IntegrationContractTests/test_default_offline_grace_period_is_seven_days`

Expected: PASS

**Step 5: Commit**

```bash
git add Tests/DemoSharedTests/IntegrationContractTests.swift docs/runbooks/manual-test-matrix.md docs/runbooks/lab-setup.md docs/runbooks/known-limitations.md Sources/DemoShared/Config.swift
git commit -m "docs: add integration contract and test matrix"
```

## Task 10: Verification Gate Before Claiming Demo Completeness

**Files:**
- Modify: `docs/runbooks/manual-test-matrix.md`
- Modify: `docs/runbooks/known-limitations.md`

**Step 1: Run package tests**

Run: `swift test`

Expected: PASS

**Step 2: Run Xcode target tests**

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginPlugin -destination 'platform=macOS'`

Expected: PASS

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme LoginUI -destination 'platform=macOS'`

Expected: PASS

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme AccountSyncDaemon -destination 'platform=macOS'`

Expected: PASS

Run: `xcodebuild test -project macos/DemoSSO.xcodeproj -scheme StatusAgent -destination 'platform=macOS'`

Expected: PASS

**Step 3: Run installer dry-run**

Run: `bash scripts/install-jamf-style-demo.sh --dry-run`

Expected: PASS

**Step 4: Perform manual lab validation**

Run the documented scenarios from `docs/runbooks/manual-test-matrix.md` on a macOS 11+ test machine with an admin account.

Expected:

- login interception works
- online and offline paths behave as designed
- uninstall restores native loginwindow behavior

**Step 5: Commit release-ready state**

```bash
git add .
git commit -m "feat: complete jamf-style loginwindow sso demo"
```

## Implementation Notes

- Prefer a root-owned mapping directory under `/Library/Application Support/DemoSSO/` rather than user home storage.
- Keep the demo IdP local and deterministic. Avoid adding real OIDC dependencies in phase 1.
- Treat SecureToken and FileVault as phase 2 unless the phase-1 login handoff is already stable.
- Keep one local admin outside the SSO flow for break-glass recovery.
- Use `@test-driven-development` and `@verification-before-completion` principles while executing this plan.

## Suggested Execution Order

1. Complete Tasks 1 through 3 inside the Swift package to stabilize shared contracts first.
2. Complete Task 4 before Task 7 so the login plug-in has a daemon contract to call.
3. Complete Task 6 before Task 7 so the plug-in can invoke a real UI shell.
4. Leave live install and loginwindow interception until Tasks 8 through 10.
