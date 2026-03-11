import XCTest
@testable import DemoShared

final class PasswordSyncCoordinatorTests: XCTestCase {
    func test_sync_request_marks_local_password_for_rotation_when_fingerprints_differ() {
        let coordinator = PasswordSyncCoordinator()
        let action = coordinator.reconcile(localPasswordFingerprint: "old", remotePasswordFingerprint: "new")

        XCTAssertEqual(action, .rotateLocalPassword)
    }

    func test_sync_request_is_noop_when_fingerprints_match() {
        let coordinator = PasswordSyncCoordinator()
        let action = coordinator.reconcile(localPasswordFingerprint: "same", remotePasswordFingerprint: "same")

        XCTAssertEqual(action, .noop)
    }
}
