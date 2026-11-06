import Foundation

enum CloudTranscriptionError: Error, LocalizedError {
    case unsupportedProvider
    case unsupportedModel(String)
    case missingAPIKey
    case invalidAPIKey
    case audioFileNotFound
    case apiRequestFailed(statusCode: Int, message: String)
    case networkError(Error)
    case noTranscriptionReturned
    case dataEncodingError

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return String(localized: "The model provider is not supported by this service.")
        case .unsupportedModel(let model):
            return String(format: String(localized: "The selected model is not supported: %@"), model)
        case .missingAPIKey:
            return String(localized: "API key for this service is missing. Please configure it in the settings.")
        case .invalidAPIKey:
            return String(localized: "The provided API key is invalid.")
        case .audioFileNotFound:
            return String(localized: "The audio file to transcribe could not be found.")
        case .apiRequestFailed(let statusCode, let message):
            return String(
                format: String(localized: "The API request failed with status code %lld: %@"), Int64(statusCode),
                message)
        case .networkError(let error):
            return String(format: String(localized: "A network error occurred: %@"), error.localizedDescription)
        case .noTranscriptionReturned:
            return String(localized: "The API returned an empty or invalid response.")
        case .dataEncodingError:
            return String(localized: "Failed to encode the request body.")
        }
    }
}
