import Foundation

/// Transcribes with a user-configured OpenAI-compatible endpoint (`ModelProvider.custom`).
/// Compiled in every build. On-device builds only reach loopback hosts or hosts the user
/// has confirmed (`LocalEndpoint.requirePermitted`).
final class CustomEndpointTranscriptionService: TranscriptionService {
    private lazy var openAICompatibleService = OpenAICompatibleTranscriptionService()

    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws
        -> String
    {
        try Task.checkCancellation()

        guard let customModel = model as? CustomCloudModel else {
            throw ProviderPolicyError.providerNotAllowed(model.provider.rawValue)
        }

        guard let endpointURL = URL(string: customModel.apiEndpoint) else {
            // Same error the custom path produced before: OpenAICompatibleTranscriptionService's
            // invalid-URL NSError, wrapped as a network error by the former cloud service.
            throw CloudTranscriptionError.networkError(
                NSError(
                    domain: "CustomWhisperTranscriptionService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint URL"]))
        }
        try LocalEndpoint.requirePermitted(endpointURL)

        do {
            return try await openAICompatibleService.transcribe(
                audioURL: audioURL, model: customModel, context: context,
                timeout: CloudTranscriptionSettings.timeout)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CloudTranscriptionError {
            throw error
        } catch {
            try Task.checkCancellation()
            throw CloudTranscriptionError.networkError(error)
        }
    }
}
