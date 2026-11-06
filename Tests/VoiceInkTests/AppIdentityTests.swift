import XCTest
@testable import VoiceInk

final class AppIdentityTests: XCTestCase {

    func testBundleIdentifierMatchesMainBundle() {
        XCTAssertEqual(
            AppIdentity.bundleIdentifier,
            Bundle.main.bundleIdentifier ?? AppIdentity.fallbackBundleIdentifier
        )
    }

    func testSupportFolderIsBundleIdentifier() {
        XCTAssertEqual(AppIdentity.applicationSupportFolderName, AppIdentity.bundleIdentifier)
    }

    func testNoUpstreamIdentifier() {
        let values = [
            AppIdentity.bundleIdentifier,
            AppIdentity.keychainService,
            AppIdentity.localKeychainService,
            AppIdentity.loggerSubsystem,
            AppIdentity.iCloudContainerIdentifier,
        ]
        for value in values {
            XCTAssertFalse(value.contains("prakashjoshipax"), "\(value) still names the upstream identifier")
        }
    }
}
