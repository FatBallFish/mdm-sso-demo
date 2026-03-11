import XCTest
@testable import DemoShared

final class MappingStoreTests: XCTestCase {
    func test_round_trip_mapping_persists_subject_and_local_user() throws {
        let store = MappingStore(baseURL: FileManager.default.temporaryDirectory)
        let record = AccountMapping(
            ssoSubject: "demo.user",
            localShortName: "demouser",
            lastOnlineAuthAt: Date(timeIntervalSince1970: 1_000),
            offlineGraceExpiry: Date(timeIntervalSince1970: 2_000),
            lastTokenRefreshAt: nil
        )

        try store.save(record)
        let loaded = try store.load(subject: "demo.user")

        XCTAssertEqual(loaded?.localShortName, "demouser")
    }
}
