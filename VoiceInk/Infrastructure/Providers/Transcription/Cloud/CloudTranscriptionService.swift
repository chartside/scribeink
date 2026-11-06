#if CLOUD_PROVIDERS
import Foundation
import LLMkit

class CloudTranscriptionService: TranscriptionService {
    private lazy var openAICompatibleService = OpenAICompatibleTranscriptionService()

    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws
        -> String
    {
        try Task.checkCancellation()
        let audioData = try loadAudioData(from: audioURL)
        let fileName = audioURL.lastPathComponent
        let language = selectedLanguage(from: context)
        let timeout = CloudTranscriptionSettings.timeout

        do {
            if model.provider == .custom {
                guard let customModel = model as? CustomCloudModel else {
                    throw CloudTranscriptionError.unsupportedProvider
                }
                return try await openAICompatibleService.transcribe(
                    audioURL: audioURL, model: customModel, context: context, timeout: timeout)
            }

            guard let cloudProvider = CloudProviderRegistry.provider(for: model.provider) else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            let apiKey = try requireAPIKey(forProvider: cloudProvider.providerKey)
            return try await cloudProvider.transcribe(
                audioData: audioData,
                fileName: fileName,
                apiKey: apiKey,
                model: model.name,
                language: language,
                customVocabulary: context.vocabulary?.terms ?? [],
                timeout: timeout
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CloudTranscriptionError {
            throw error
        } catch let error as LLMKitError {
            try Task.checkCancellation()
            throw mapLLMKitError(error)
        } catch {
            try Task.checkCancellation()
            throw CloudTranscriptionError.networkError(error)
        }
    }

    // MARK: - Helpers

    private func loadAudioData(from url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CloudTranscriptionError.audioFileNotFound
        }
        return try Data(contentsOf: url)
    }

    private func requireAPIKey(forProvider provider: String) throws -> String {
        guard let apiKey = APIKeyManager.shared.getAPIKey(forProvider: provider), !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        return apiKey
    }

    private func selectedLanguage(from context: TranscriptionRequestContext) -> String? {
        let lang = context.language ?? "auto"
        return (lang == "auto" || lang.isEmpty) ? nil : lang
    }

    private func mapLLMKitError(_ error: LLMKitError) -> CloudTranscriptionError {
        switch error {
        case .missingAPIKey:
            return .missingAPIKey
        case .httpError(let statusCode, let message):
            return .apiRequestFailed(statusCode: statusCode, message: message)
        case .noResultReturned:
            return .noTranscriptionReturned
        case .encodingError:
            return .dataEncodingError
        case .networkError(let detail):
            return .networkError(NSError(domain: "LLMkit", code: -1, userInfo: [NSLocalizedDescriptionKey: detail]))
        case .invalidURL, .decodingError, .timeout:
            return .networkError(error)
        case .unsupportedModel(let model):
            return .unsupportedModel(model)
        }
    }
}
#endif
