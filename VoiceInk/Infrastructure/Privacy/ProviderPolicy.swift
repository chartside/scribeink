import Foundation

/// The single place that decides which transcription and AI providers are
/// allowed. On-device builds allow only providers that run locally or that the
/// user points at an endpoint they control. Builds compiled with
/// `CLOUD_PROVIDERS` allow everything.
enum ProviderPolicy {
    #if CLOUD_PROVIDERS
    static let allowsCloud: Bool = true
    #else
    static let allowsCloud: Bool = false
    #endif

    static func isAllowed(_ provider: ModelProvider, allowsCloud: Bool = ProviderPolicy.allowsCloud) -> Bool {
        if allowsCloud { return true }
        // Every case is listed on purpose: a new upstream case must be classified before this compiles.
        switch provider {
        case .whisper: return true
        case .fluidAudio: return true
        case .transcribeCpp: return true
        case .nativeApple: return true
        case .custom: return true
        case .groq: return false
        case .elevenLabs: return false
        case .deepgram: return false
        case .mistral: return false
        case .gemini: return false
        case .soniox: return false
        case .speechmatics: return false
        case .assemblyAI: return false
        case .xai: return false
        case .cartesia: return false
        case .openRouter: return false
        }
    }

    static func isAllowed(_ provider: AIProvider, allowsCloud: Bool = ProviderPolicy.allowsCloud) -> Bool {
        if allowsCloud { return true }
        // Every case is listed on purpose: a new upstream case must be classified before this compiles.
        switch provider {
        case .voiceInkRefine: return true
        case .ollama: return true
        case .custom: return true
        case .cerebras: return false
        case .groq: return false
        case .gemini: return false
        case .anthropic: return false
        case .openAI: return false
        case .openRouter: return false
        case .mistral: return false
        case .elevenLabs: return false
        case .deepgram: return false
        case .soniox: return false
        case .speechmatics: return false
        case .assemblyAI: return false
        case .localCLI: return false
        }
    }
}

enum ProviderPolicyError: LocalizedError, Equatable {
    /// The associated value is the provider's display name.
    case providerNotAllowed(String)
    case remoteEndpointNotConfirmed(host: String)

    var errorDescription: String? {
        switch self {
        case .providerNotAllowed(let name):
            return String(format: String(localized: "%@ is not available in on-device builds."), name)
        case .remoteEndpointNotConfirmed:
            return "Remote endpoint not confirmed"
        }
    }
}
