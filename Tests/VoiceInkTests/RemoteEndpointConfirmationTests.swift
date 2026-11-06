import XCTest
@testable import VoiceInk

final class RemoteEndpointConfirmationTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RemoteEndpointConfirmationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func needs(_ urlString: String) -> String? {
        RemoteEndpointConfirmation.hostNeedingConfirmation(for: urlString, allowsCloud: false, defaults: defaults)
    }

    func testLoopbackNeedsNoConfirmation() {
        XCTAssertNil(needs("http://localhost:11434"))
        XCTAssertNil(needs("http://127.0.0.1:8080/v1/audio/transcriptions"))
        XCTAssertNil(needs("http://[::1]:11434"))
    }

    func testAcceptedHostNeedsNoConfirmation() {
        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        XCTAssertNil(needs("http://192.168.1.20:11434"))
    }

    func testAcceptedHostMatchesCaseInsensitively() {
        LocalEndpoint.accept(host: "Server.Local", defaults: defaults)
        XCTAssertNil(needs("http://SERVER.local:8080/v1"))
    }

    func testNewLANAddressNeedsConfirmation() {
        XCTAssertEqual(needs("http://192.168.1.20:11434"), "192.168.1.20")
    }

    func testDifferentHostWarnsAgainAfterAcceptingOne() {
        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        XCTAssertEqual(needs("http://192.168.1.21:11434"), "192.168.1.21")
    }

    func testHostIsReturnedLowerCased() {
        XCTAssertEqual(needs("https://Whisper.Clinic.Example/v1"), "whisper.clinic.example")
    }

    func testLookAlikeLoopbackNeedsConfirmation() {
        XCTAssertEqual(needs("http://localhost.evil.example"), "localhost.evil.example")
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(needs("  http://192.168.1.20:11434\n"), "192.168.1.20")
        XCTAssertNil(needs("  http://localhost:11434  "))
    }

    func testEmptyOrMalformedNeedsNoConfirmation() {
        XCTAssertNil(needs(""))
        XCTAssertNil(needs("   "))
        XCTAssertNil(needs("not a url"))
        XCTAssertNil(needs("192.168.1.20:11434"))
    }

    func testRemoteHostIgnoresAcceptance() {
        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        XCTAssertEqual(RemoteEndpointConfirmation.remoteHost(for: "http://192.168.1.20:11434", allowsCloud: false), "192.168.1.20")
        XCTAssertNil(RemoteEndpointConfirmation.remoteHost(for: "http://localhost:11434", allowsCloud: false))
        XCTAssertNil(RemoteEndpointConfirmation.remoteHost(for: "", allowsCloud: false))
    }

    func testCloudBuildsNeverWarnOrLabel() {
        XCTAssertNil(
            RemoteEndpointConfirmation.hostNeedingConfirmation(
                for: "http://192.168.1.20:11434", allowsCloud: true, defaults: defaults))
        XCTAssertNil(RemoteEndpointConfirmation.remoteHost(for: "http://192.168.1.20:11434", allowsCloud: true))
    }

    func testCopy() {
        XCTAssertEqual(
            RemoteEndpointConfirmation.warningMessage(host: "192.168.1.20"),
            "This sends audio or transcripts containing patient information to 192.168.1.20. Only use a server you control inside your clinic."
        )
        XCTAssertEqual(RemoteEndpointConfirmation.remoteLabel(host: "192.168.1.20"), "Remote: 192.168.1.20")
    }
}
