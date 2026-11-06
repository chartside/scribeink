import XCTest
@testable import VoiceInk

final class OnDeviceReadinessTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnDeviceReadinessTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create UserDefaults suite \(suiteName)")
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func localModel() -> any TranscriptionModel {
        NativeAppleModel(
            name: "apple-speech",
            displayName: "Apple Speech",
            description: "Synthetic test model",
            isMultilingualModel: true,
            supportedLanguages: [:]
        )
    }

    private func mode(
        transcriptionKey: String? = nil,
        enhancementEnabled: Bool = false,
        aiProvider: String? = nil
    ) -> ModeConfig {
        ModeConfig(
            name: "Test Mode",
            isAIEnhancementEnabled: enhancementEnabled,
            selectedTranscriptionModelName: transcriptionKey,
            selectedAIProvider: aiProvider
        )
    }

    // MARK: - Enhancement

    @MainActor
    func testEnhancementBlockedForCloudProviderOnDevice() {
        XCTAssertTrue(OnDeviceReadiness.enhancementBlocked(.openAI, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.enhancementBlocked(.ollama, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.enhancementBlocked(.custom, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.enhancementBlocked(.openAI, allowsCloud: true))
    }

    @MainActor
    func testBlockedEnhancementProviderReadsStoredModeProvider() {
        let cloudMode = mode(enhancementEnabled: true, aiProvider: AIProvider.openAI.rawValue)
        XCTAssertEqual(OnDeviceReadiness.blockedEnhancementProvider(for: cloudMode, allowsCloud: false), .openAI)
        XCTAssertNil(OnDeviceReadiness.blockedEnhancementProvider(for: cloudMode, allowsCloud: true))

        let disabled = mode(enhancementEnabled: false, aiProvider: AIProvider.openAI.rawValue)
        XCTAssertNil(OnDeviceReadiness.blockedEnhancementProvider(for: disabled, allowsCloud: false))

        let local = mode(enhancementEnabled: true, aiProvider: AIProvider.ollama.rawValue)
        XCTAssertNil(OnDeviceReadiness.blockedEnhancementProvider(for: local, allowsCloud: false))

        let unset = mode(enhancementEnabled: true, aiProvider: nil)
        XCTAssertNil(OnDeviceReadiness.blockedEnhancementProvider(for: unset, allowsCloud: false))
        XCTAssertNil(OnDeviceReadiness.blockedEnhancementProvider(for: nil, allowsCloud: false))
    }

    // MARK: - Stale selection keys

    @MainActor
    func testFilteredSelectionDetectsUnknownNonCustomKey() {
        let known = [localModel()]
        XCTAssertTrue(OnDeviceReadiness.isFilteredSelection("whisper-large-v3", knownModels: known, allowsCloud: false))
        XCTAssertTrue(OnDeviceReadiness.isFilteredSelection("OpenRouter:synthetic", knownModels: known, allowsCloud: false))
    }

    @MainActor
    func testFilteredSelectionIgnoresKnownCustomEmptyAndCloudBuilds() {
        let known = [localModel()]
        XCTAssertFalse(OnDeviceReadiness.isFilteredSelection("apple-speech", knownModels: known, allowsCloud: false))
        XCTAssertFalse(
            OnDeviceReadiness.isFilteredSelection("Custom:\(UUID().uuidString)", knownModels: known, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.isFilteredSelection(nil, knownModels: known, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.isFilteredSelection("  ", knownModels: known, allowsCloud: false))
        XCTAssertFalse(OnDeviceReadiness.isFilteredSelection("whisper-large-v3", knownModels: known, allowsCloud: true))
    }

    // MARK: - Transcription resolution

    @MainActor
    func testTranscriptionBlockedForModeWithFilteredModel() {
        let defaults = makeDefaults()
        let resolution = ModeTranscriptionModelResolution.modelNotFound(mode: mode(transcriptionKey: "whisper-large-v3"))
        XCTAssertTrue(
            OnDeviceReadiness.transcriptionBlocked(
                resolution, knownModels: [localModel()], defaults: defaults, allowsCloud: false))
        XCTAssertFalse(
            OnDeviceReadiness.transcriptionBlocked(
                resolution, knownModels: [localModel()], defaults: defaults, allowsCloud: true))
    }

    @MainActor
    func testTranscriptionNotBlockedForAvailableLocalModel() {
        let defaults = makeDefaults()
        let model = localModel()
        let resolution = ModeTranscriptionModelResolution.available(mode: mode(transcriptionKey: model.selectionKey), model: model)
        XCTAssertFalse(
            OnDeviceReadiness.transcriptionBlocked(resolution, knownModels: [model], defaults: defaults, allowsCloud: false))
    }

    @MainActor
    func testNoSelectionChecksGlobalKey() {
        let defaults = makeDefaults()
        let resolution = ModeTranscriptionModelResolution.noSelection(mode: mode())
        XCTAssertFalse(
            OnDeviceReadiness.transcriptionBlocked(
                resolution, knownModels: [localModel()], defaults: defaults, allowsCloud: false))

        defaults.set("whisper-large-v3", forKey: OnDeviceReadiness.globalTranscriptionSelectionKey)
        XCTAssertTrue(
            OnDeviceReadiness.transcriptionBlocked(
                resolution, knownModels: [localModel()], defaults: defaults, allowsCloud: false))
        // The check only reads the saved value.
        XCTAssertEqual(defaults.string(forKey: OnDeviceReadiness.globalTranscriptionSelectionKey), "whisper-large-v3")
    }

    @MainActor
    func testNilConfigurationIsNotBlocked() {
        XCTAssertFalse(OnDeviceReadiness.transcriptionBlocked(nil, allowsCloud: false))
    }
}
