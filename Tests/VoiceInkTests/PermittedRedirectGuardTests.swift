import XCTest
@testable import VoiceInk

final class PermittedRedirectGuardTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        suiteName = "PermittedRedirectGuardTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        session = URLSession(configuration: .ephemeral)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            fatalError("Invalid test URL: \(string)")
        }
        return url
    }

    /// Calls the guard's redirect callback directly and returns what it passed to the handler.
    private func redirect(to target: String, using redirectGuard: PermittedRedirectGuard) -> (called: Bool, request: URLRequest?) {
        let origin = url("http://localhost:9000/v1/audio/transcriptions")
        let task = session.dataTask(with: origin)
        let response = HTTPURLResponse(
            url: origin, statusCode: 307, httpVersion: "HTTP/1.1", headerFields: ["Location": target])!
        var called = false
        var result: URLRequest?
        redirectGuard.urlSession(
            session, task: task, willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: url(target))
        ) { request in
            called = true
            result = request
        }
        task.cancel()
        return (called, result)
    }

    func testRedirectToUnconfirmedRemoteHostIsRefusedOnDevice() {
        let redirectGuard = PermittedRedirectGuard(allowsCloud: false, defaults: defaults)
        let outcome = redirect(to: "http://192.168.1.20/x", using: redirectGuard)
        XCTAssertTrue(outcome.called)
        XCTAssertNil(outcome.request)
    }

    func testRedirectToLoopbackIsFollowedOnDevice() {
        let redirectGuard = PermittedRedirectGuard(allowsCloud: false, defaults: defaults)
        let outcome = redirect(to: "http://localhost:9000/x", using: redirectGuard)
        XCTAssertTrue(outcome.called)
        XCTAssertEqual(outcome.request?.url, url("http://localhost:9000/x"))
    }

    func testRedirectToAcceptedHostIsFollowedOnDevice() {
        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        let redirectGuard = PermittedRedirectGuard(allowsCloud: false, defaults: defaults)
        let outcome = redirect(to: "http://192.168.1.20/x", using: redirectGuard)
        XCTAssertEqual(outcome.request?.url, url("http://192.168.1.20/x"))
    }

    func testRedirectToRemoteHostIsFollowedWhenCloudAllowed() {
        let redirectGuard = PermittedRedirectGuard(allowsCloud: true, defaults: defaults)
        let outcome = redirect(to: "http://192.168.1.20/x", using: redirectGuard)
        XCTAssertEqual(outcome.request?.url, url("http://192.168.1.20/x"))
    }
}
