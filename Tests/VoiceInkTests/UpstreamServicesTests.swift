import XCTest
@testable import VoiceInk

final class UpstreamServicesTests: XCTestCase {

    func testAllUpstreamServicesOff() {
        XCTAssertFalse(UpstreamServices.updatesEnabled)
        XCTAssertFalse(UpstreamServices.licensingEnabled)
        XCTAssertFalse(UpstreamServices.announcementsEnabled)
        XCTAssertFalse(UpstreamServices.starPromptEnabled)
    }

    func testSupportURL() {
        XCTAssertEqual(UpstreamServices.supportURL.absoluteString, "https://github.com/chartside/scribeink")
    }

    @MainActor
    func testUpdaterUnavailable() {
        // Constructed the way VoiceInkApp.init does. With updates off this must not create or start Sparkle.
        let updater = UpdaterViewModel()
        XCTAssertFalse(updater.isAvailable)
        XCTAssertFalse(updater.canCheckForUpdates)
    }

    @MainActor
    func testLicensingOffBehavesAsLicensed() {
        let viewModel = LicenseViewModel.shared
        XCTAssertEqual(viewModel.licenseState, .licensed)
        XCTAssertTrue(viewModel.canUseApp)
        XCTAssertNil(viewModel.usageRestrictionMessage)
    }
}
