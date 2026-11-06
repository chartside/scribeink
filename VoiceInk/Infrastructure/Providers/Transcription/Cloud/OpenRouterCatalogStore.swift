import Foundation
import LLMkit

/// Shared persistence for OpenRouter's separate text and speech-to-text catalogs.
final class OpenRouterCatalogStore: @unchecked Sendable {
    enum Kind: String {
        case enhancement = "openRouterModelCatalog"
        case transcription = "openRouterTranscriptionModelCatalog"
    }

    static let shared = OpenRouterCatalogStore()

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private var catalogs: [Kind: [OpenRouterModel]] = [:]

    private init() {
        for kind in [Kind.enhancement, .transcription] {
            guard let data = defaults.data(forKey: kind.rawValue),
                let models = try? JSONDecoder().decode([OpenRouterModel].self, from: data)
            else { continue }
            catalogs[kind] = models
        }
    }

    func models(for kind: Kind) -> [OpenRouterModel]? {
        lock.lock()
        defer { lock.unlock() }
        return catalogs[kind]
    }

    func save(_ models: [OpenRouterModel], for kind: Kind) throws {
        let data = try JSONEncoder().encode(models)
        defaults.set(data, forKey: kind.rawValue)
        lock.lock()
        catalogs[kind] = models
        lock.unlock()
    }

    var legacyEnhancementModelIDs: [String] {
        defaults.array(forKey: "openRouterModels") as? [String] ?? []
    }

    func saveLegacyEnhancementModelIDs(_ ids: [String]) {
        defaults.set(ids, forKey: "openRouterModels")
    }
}
