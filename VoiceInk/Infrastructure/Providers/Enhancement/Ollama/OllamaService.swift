import Foundation
import LLMkit
import SwiftUI

class OllamaService: ObservableObject {
    static let defaultBaseURL = "http://localhost:11434"

    // MARK: - Published Properties
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "ollamaBaseURL")
        }
    }

    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "ollamaSelectedModel")
        }
    }

    @Published var availableModels: [OllamaModel] = []
    @Published var isConnected: Bool = false
    @Published var isLoadingModels: Bool = false

    private let defaultTemperature: Double = 0.3

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? Self.defaultBaseURL
        self.selectedModel = UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "llama2"
    }

    private var baseURLValue: URL? {
        URL(string: baseURL)
    }

    /// Every probe (connection check, model list) passes through here, so no caller can contact
    /// an unconfirmed remote host in an on-device build. Cloud builds always pass.
    private var probeURL: URL? {
        guard let url = baseURLValue, LocalEndpoint.isPermitted(url) else { return nil }
        return url
    }

    @MainActor
    func checkConnection() async {
        guard let url = probeURL else {
            isConnected = false
            return
        }
        isConnected = await OllamaClient.checkConnection(baseURL: url)
    }

    @MainActor
    func refreshModels() async {
        _ = await refreshConnectionAndModels()
    }

    @MainActor
    func refreshConnectionAndModels() async -> Result<[OllamaModel], Error> {
        isLoadingModels = true
        defer { isLoadingModels = false }

        guard let url = baseURLValue else {
            isConnected = false
            availableModels = []
            return .failure(LocalAIError.invalidURL)
        }
        guard probeURL != nil else {
            isConnected = false
            availableModels = []
            return .failure(ProviderPolicyError.remoteEndpointNotConfirmed(host: url.host ?? ""))
        }

        do {
            let models = try await OllamaClient.fetchModels(baseURL: url)
            isConnected = true
            availableModels = models

            if !models.contains(where: { $0.name == selectedModel }) && !models.isEmpty {
                selectedModel = models[0].name
            }

            return .success(models)
        } catch {
            isConnected = false
            availableModels = []
            return .failure(error)
        }
    }

    func enhance(
        _ text: String,
        withSystemPrompt systemPrompt: String? = nil,
        model: String? = nil,
        timeout: TimeInterval = 30,
        retryOnTimeout: Bool = false
    ) async throws -> String {
        guard let systemPrompt = systemPrompt else {
            throw LocalAIError.invalidRequest
        }

        guard let url = baseURLValue else {
            throw LocalAIError.invalidURL
        }

        let trimmedModel = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestModel = (trimmedModel?.isEmpty == false ? trimmedModel : nil) ?? selectedModel

        do {
            return try await OllamaClient.generate(
                baseURL: url,
                model: requestModel,
                prompt: text,
                systemPrompt: systemPrompt,
                options: OllamaGenerationOptions(temperature: defaultTemperature),
                think: false,
                timeout: timeout,
                retryOnTimeout: retryOnTimeout
            )
        } catch let error as LLMKitError {
            throw mapLLMKitError(error)
        }
    }

    private func mapLLMKitError(_ error: LLMKitError) -> LocalAIError {
        switch error {
        case .invalidURL:
            return .invalidURL
        case .httpError(let statusCode, _):
            if statusCode == 404 { return .modelNotFound }
            if statusCode == 408 { return .timeout }
            if statusCode == 500 { return .serverError }
            return .invalidResponse
        case .networkError:
            return .serviceUnavailable
        case .noResultReturned, .decodingError:
            return .invalidResponse
        case .encodingError:
            return .invalidRequest
        case .missingAPIKey:
            return .invalidResponse
        case .timeout:
            return .timeout
        case .unsupportedModel:
            return .modelNotFound
        }
    }
}

// MARK: - Error Types
enum LocalAIError: Error, LocalizedError {
    case invalidURL
    case serviceUnavailable
    case invalidResponse
    case modelNotFound
    case serverError
    case invalidRequest
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid Ollama server URL")
        case .serviceUnavailable:
            return String(localized: "Ollama service is not available")
        case .invalidResponse:
            return String(localized: "Invalid response from Ollama server")
        case .modelNotFound:
            return String(localized: "Selected model not found")
        case .serverError:
            return String(localized: "Ollama server error")
        case .invalidRequest:
            return String(localized: "System prompt is required")
        case .timeout:
            return String(localized: "Ollama request timed out")
        }
    }
}
