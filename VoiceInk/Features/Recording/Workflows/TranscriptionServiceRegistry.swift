import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
class TranscriptionServiceRegistry {
    private weak var modelProvider: (any WhisperModelProvider)?
    private let modelsDirectory: URL
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionServiceRegistry")

    private(set) lazy var localTranscriptionService = WhisperTranscriptionService(
        modelsDirectory: modelsDirectory,
        modelProvider: modelProvider
    )
    #if CLOUD_PROVIDERS
    private(set) lazy var cloudTranscriptionService = CloudTranscriptionService()
    #endif
    private(set) lazy var customEndpointTranscriptionService = CustomEndpointTranscriptionService()
    private(set) lazy var nativeAppleTranscriptionService = NativeAppleTranscriptionService()
    private(set) lazy var fluidAudioTranscriptionService = FluidAudioTranscriptionService()
    private var cachedTranscribeCppTranscriptionService: TranscribeCppTranscriptionService?

    var transcribeCppTranscriptionService: TranscribeCppTranscriptionService {
        if let cachedTranscribeCppTranscriptionService {
            return cachedTranscribeCppTranscriptionService
        }
        let service = TranscribeCppTranscriptionService()
        cachedTranscribeCppTranscriptionService = service
        return service
    }

    init(modelProvider: any WhisperModelProvider, modelsDirectory: URL, modelContext: ModelContext) {
        self.modelProvider = modelProvider
        self.modelsDirectory = modelsDirectory
        self.modelContext = modelContext
    }

    func service(for provider: ModelProvider) -> TranscriptionService {
        switch provider {
        case .whisper:
            return localTranscriptionService
        case .fluidAudio:
            return fluidAudioTranscriptionService
        case .transcribeCpp:
            return transcribeCppTranscriptionService
        case .nativeApple:
            return nativeAppleTranscriptionService
        case .custom:
            return customEndpointTranscriptionService
        default:
            #if CLOUD_PROVIDERS
            return cloudTranscriptionService
            #else
            return DeniedTranscriptionService()
            #endif
        }
    }

    func transcribe(
        audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext = .currentDefaults
    ) async throws -> String {
        try ProviderPolicy.requireAllowed(model.provider)
        let service = service(for: model.provider)
        logger.debug(
            "Transcribing with \(model.displayName, privacy: .public) using \(String(describing: type(of: service)), privacy: .public)"
        )
        let vocabulary = context.vocabulary ?? CustomVocabularyService.shared.loadSavedVocabulary(from: modelContext)
        return try await service.transcribe(
            audioURL: audioURL, model: model, context: context.withVocabulary(vocabulary).scoped(to: model)
        )
    }

    /// Creates a streaming or file-based session for the resolved transcription configuration.
    func createSession(
        for configuration: TranscriptionRuntimeConfiguration, onPartialTranscript: ((String) -> Void)? = nil
    ) -> TranscriptionSession {
        let model = configuration.model

        // Policy check comes first so a denied provider can never reach the streaming path.
        // This method can't throw, so the refusal surfaces when the session transcribes.
        do {
            try ProviderPolicy.requireAllowed(model.provider)
        } catch {
            logger.error(
                "Refusing transcription session for disallowed provider \(model.provider.rawValue, privacy: .public)"
            )
            return FileTranscriptionSession(service: DeniedTranscriptionService())
        }

        if shouldUseRealtimeTranscription(for: configuration) {
            let streamingService = StreamingTranscriptionService(
                fluidAudioService: model.provider == .fluidAudio ? fluidAudioTranscriptionService : nil,
                onPartialTranscript: onPartialTranscript
            )
            let fallback = service(for: model.provider)
            return StreamingTranscriptionSession(streamingService: streamingService, fallbackService: fallback)
        } else {
            return FileTranscriptionSession(service: service(for: model.provider))
        }
    }

    /// Whether the resolved transcription configuration should use real-time transcription.
    func shouldUseRealtimeTranscription(for configuration: TranscriptionRuntimeConfiguration) -> Bool {
        configuration.isRealtimeEnabled && ProviderPolicy.isAllowed(configuration.model.provider)
    }

    func cleanup() async {
        await fluidAudioTranscriptionService.cleanup()
        cachedTranscribeCppTranscriptionService?.cleanup()
    }
}

/// Backstop: any provider the policy refuses that reaches the registry is refused here.
/// Used by `service(for:)` in on-device builds and by `createSession` in every build
/// (in CLOUD_PROVIDERS builds the policy allows everything, so it is never reached there).
private struct DeniedTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws
        -> String
    {
        throw ProviderPolicyError.providerNotAllowed(model.provider.rawValue)
    }
}
