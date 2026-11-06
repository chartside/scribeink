import XCTest
@testable import VoiceInk

final class ProviderPolicyTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ProviderPolicyTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
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

    func testAllowedTranscriptionProvidersOnDevice() {
        let expected: Set<ModelProvider> = [.whisper, .fluidAudio, .transcribeCpp, .nativeApple, .custom]
        for provider in ModelProvider.allCases {
            XCTAssertEqual(
                ProviderPolicy.isAllowed(provider, allowsCloud: false),
                expected.contains(provider),
                "Unexpected on-device result for \(provider.rawValue)"
            )
        }
    }

    func testAllowedAIProvidersOnDevice() {
        let expected: Set<AIProvider> = [.voiceInkRefine, .ollama, .custom]
        for provider in AIProvider.allCases {
            XCTAssertEqual(
                ProviderPolicy.isAllowed(provider, allowsCloud: false),
                expected.contains(provider),
                "Unexpected on-device result for \(provider.rawValue)"
            )
        }
    }

    func testEverythingAllowedWithCloud() {
        for provider in ModelProvider.allCases {
            XCTAssertTrue(ProviderPolicy.isAllowed(provider, allowsCloud: true), provider.rawValue)
        }
        for provider in AIProvider.allCases {
            XCTAssertTrue(ProviderPolicy.isAllowed(provider, allowsCloud: true), provider.rawValue)
        }
    }

    func testLoopback() {
        let loopbackURLs = [
            "http://localhost:11434",
            "http://LOCALHOST",
            "http://127.0.0.1",
            "http://127.5.5.5:8080/v1",
            "http://[::1]:11434"
        ]
        for string in loopbackURLs {
            XCTAssertTrue(LocalEndpoint.isLoopback(url(string)), string)
        }
    }

    func testLoopbackLookAlikes() {
        let nonLoopbackURLs = [
            "http://localhost.evil.com",
            "http://127.0.0.1.nip.io",
            "http://0.0.0.0:11434",
            "http://192.168.1.20:11434",
            "http://10.0.0.5",
            "https://api.openai.com"
        ]
        for string in nonLoopbackURLs {
            XCTAssertFalse(LocalEndpoint.isLoopback(url(string)), string)
        }
    }

    func testAcceptedHostIsCaseInsensitiveAndPortIndependent() {
        LocalEndpoint.accept(host: "Server.Local", defaults: defaults)
        XCTAssertTrue(
            LocalEndpoint.isPermitted(url("http://server.local:8080/v1"), allowsCloud: false, defaults: defaults)
        )
        XCTAssertFalse(
            LocalEndpoint.isPermitted(url("http://other.local"), allowsCloud: false, defaults: defaults)
        )
    }

    func testRequirePermittedThrows() {
        XCTAssertThrowsError(
            try LocalEndpoint.requirePermitted(url("http://192.168.1.20"), allowsCloud: false, defaults: defaults)
        ) { error in
            XCTAssertEqual(
                error as? ProviderPolicyError,
                ProviderPolicyError.remoteEndpointNotConfirmed(host: "192.168.1.20")
            )
        }
    }

    func testRequireAllowedThrowsForCloudOnDevice() {
        XCTAssertThrowsError(try ProviderPolicy.requireAllowed(ModelProvider.groq, allowsCloud: false)) { error in
            XCTAssertEqual(
                error as? ProviderPolicyError,
                ProviderPolicyError.providerNotAllowed(ModelProvider.groq.rawValue)
            )
        }
        XCTAssertThrowsError(try ProviderPolicy.requireAllowed(AIProvider.openAI, allowsCloud: false)) { error in
            XCTAssertEqual(
                error as? ProviderPolicyError,
                ProviderPolicyError.providerNotAllowed(AIProvider.openAI.rawValue)
            )
        }
        XCTAssertNoThrow(try ProviderPolicy.requireAllowed(ModelProvider.whisper, allowsCloud: false))
        XCTAssertNoThrow(try ProviderPolicy.requireAllowed(AIProvider.ollama, allowsCloud: false))
    }

    func testOllamaDispatchRefusesUnconfirmedHost() {
        XCTAssertEqual(
            try AIService.ollamaDispatchURL(allowsCloud: false, defaults: defaults),
            url("http://localhost:11434")
        )

        defaults.set("http://192.168.1.20:11434", forKey: "ollamaBaseURL")
        XCTAssertThrowsError(try AIService.ollamaDispatchURL(allowsCloud: false, defaults: defaults)) { error in
            XCTAssertEqual(
                error as? ProviderPolicyError,
                ProviderPolicyError.remoteEndpointNotConfirmed(host: "192.168.1.20")
            )
        }

        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        XCTAssertEqual(
            try AIService.ollamaDispatchURL(allowsCloud: false, defaults: defaults),
            url("http://192.168.1.20:11434")
        )
    }

    func testVerificationRefusesDisallowedProvidersOnDevice() {
        let refusal = AIService.verificationRefusal(for: .openRouter, allowsCloud: false)
        XCTAssertEqual(refusal?.isValid, false)
        XCTAssertEqual(
            refusal?.errorMessage,
            ProviderPolicyError.providerNotAllowed(AIProvider.openRouter.rawValue).errorDescription
        )
        XCTAssertNotNil(AIService.verificationRefusal(for: .localCLI, allowsCloud: false))
        XCTAssertNil(AIService.verificationRefusal(for: .custom, allowsCloud: false))
        XCTAssertNil(AIService.verificationRefusal(for: .ollama, allowsCloud: false))
        XCTAssertNil(AIService.verificationRefusal(for: .openRouter, allowsCloud: true))
    }

    func testOllamaBackgroundProbeSkipsUnconfirmedHost() {
        XCTAssertTrue(
            AIService.ollamaBackgroundProbePermitted(
                baseURL: "http://localhost:11434", allowsCloud: false, defaults: defaults))
        XCTAssertFalse(
            AIService.ollamaBackgroundProbePermitted(
                baseURL: "http://192.168.1.20:11434", allowsCloud: false, defaults: defaults))
        XCTAssertTrue(
            AIService.ollamaBackgroundProbePermitted(
                baseURL: "http://192.168.1.20:11434", allowsCloud: true, defaults: defaults))

        LocalEndpoint.accept(host: "192.168.1.20", defaults: defaults)
        XCTAssertTrue(
            AIService.ollamaBackgroundProbePermitted(
                baseURL: "http://192.168.1.20:11434", allowsCloud: false, defaults: defaults))
    }

    func testOnDeviceCustomEndpointDefaultsAreLoopback() throws {
        try XCTSkipIf(ProviderPolicy.allowsCloud, "Cloud builds keep upstream's pre-filled values.")
        XCTAssertTrue(LocalEndpoint.isLoopback(url(CustomEndpointDefaults.transcriptionEndpoint)))
        XCTAssertTrue(LocalEndpoint.isLoopback(url(CustomEndpointDefaults.chatBaseURL)))
        XCTAssertEqual(CustomEndpointDefaults.transcriptionModel, "")
        XCTAssertEqual(CustomEndpointDefaults.chatModel, "")
    }
}
