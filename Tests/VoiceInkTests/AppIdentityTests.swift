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

    func testBundleIdentifierIsScribeInk() {
        XCTAssertTrue(
            ["com.chartside.ScribeInk", "com.chartside.ScribeInk.dev"].contains(AppIdentity.bundleIdentifier)
        )
    }

    func testLoggerSubsystemIsLowercasedBundleIdentifier() {
        XCTAssertEqual(AppIdentity.loggerSubsystem, AppIdentity.bundleIdentifier.lowercased())
    }

    func testLocalKeychainServiceDerivesFromBundleIdentifier() {
        XCTAssertEqual(AppIdentity.localKeychainService, AppIdentity.bundleIdentifier + ".Local")
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
