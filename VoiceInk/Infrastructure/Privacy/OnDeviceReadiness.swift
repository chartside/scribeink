import AppKit
import Foundation

/// The user-facing side of `ProviderPolicy`: decides when saved settings point at a
/// provider this build does not allow, so recording can be blocked and enhancement
/// skipped with a notice. It only reads settings. It never changes a setting and never
/// reads an API key.
/// The settings page that can clear a blocked transcription selection.
enum BlockedTranscriptionRoute: Equatable {
    case modes
    case models
}

@MainActor
enum OnDeviceReadiness {
    /// The key `TranscriptionModelManager` stores the global model selection under.
    static let globalTranscriptionSelectionKey = "CurrentTranscriptionModel"

    private static var didShowLaunchNotice = false

    // MARK: - Transcription

    /// True when a resolved configuration uses a provider this build does not allow.
    static func transcriptionBlocked(
        _ config: TranscriptionRuntimeConfiguration?,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> Bool {
        guard let config else { return false }
        return !ProviderPolicy.isAllowed(config.model.provider, allowsCloud: allowsCloud)
    }

    /// Full check for a mode (nil means the current effective mode, as in `ModeRuntimeResolver`).
    /// Also catches a saved selection that no longer resolves because this build filters
    /// disallowed models out of `TranscriptionModelRegistry.models`.
    static func transcriptionBlocked(
        mode: ModeConfig? = nil,
        transcriptionModelManager: TranscriptionModelManager,
        defaults: UserDefaults = .standard,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> Bool {
        blockedTranscriptionRoute(
            mode: mode,
            transcriptionModelManager: transcriptionModelManager,
            defaults: defaults,
            allowsCloud: allowsCloud
        ) != nil
    }

    /// Where the user fixes a blocked mode, or nil when the mode is not blocked.
    static func blockedTranscriptionRoute(
        mode: ModeConfig? = nil,
        transcriptionModelManager: TranscriptionModelManager,
        defaults: UserDefaults = .standard,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> BlockedTranscriptionRoute? {
        // Cloud builds block nothing; skip resolution, whose usable-model check looks up API keys.
        guard !allowsCloud else { return nil }
        return blockedTranscriptionRoute(
            ModeRuntimeResolver.transcriptionModelResolution(
                mode: mode,
                transcriptionModelManager: transcriptionModelManager
            ),
            knownModels: transcriptionModelManager.allAvailableModels,
            defaults: defaults,
            allowsCloud: allowsCloud
        )
    }

    static func transcriptionBlocked(
        _ resolution: ModeTranscriptionModelResolution,
        knownModels: [any TranscriptionModel],
        defaults: UserDefaults = .standard,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> Bool {
        blockedTranscriptionRoute(
            resolution,
            knownModels: knownModels,
            defaults: defaults,
            allowsCloud: allowsCloud
        ) != nil
    }

    /// Pure: nil when the resolution is not blocked. A resolved model with a disallowed
    /// provider is fixed in Models; a saved selection this build filtered out is fixed in
    /// Modes, the only place that writes a mode's transcription model.
    static func blockedTranscriptionRoute(
        _ resolution: ModeTranscriptionModelResolution,
        knownModels: [any TranscriptionModel],
        defaults: UserDefaults = .standard,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> BlockedTranscriptionRoute? {
        switch resolution {
        case .available(_, let model), .unavailable(_, let model):
            return ProviderPolicy.isAllowed(model.provider, allowsCloud: allowsCloud) ? nil : .models
        case .modelNotFound(let mode):
            return isFilteredSelection(
                mode.selectedTranscriptionModelName,
                knownModels: knownModels,
                allowsCloud: allowsCloud
            ) ? .modes : nil
        case .noSelection, .noMode:
            // Modes without a selection inherit the global key on migration.
            return isFilteredSelection(
                defaults.string(forKey: globalTranscriptionSelectionKey),
                knownModels: knownModels,
                allowsCloud: allowsCloud
            ) ? .modes : nil
        }
    }

    /// True when a saved selection key names a model this build filtered out.
    ///
    /// On-device builds compile no cloud providers, so a cloud model's key cannot be looked
    /// up to read its provider. Instead: a non-empty key that matches none of the models
    /// this build knows (every local model is listed whether or not it is downloaded) is
    /// treated as disallowed. `Custom:` keys are excluded, because a missing custom model was
    /// deleted, not filtered.
    static func isFilteredSelection(
        _ key: String?,
        knownModels: [any TranscriptionModel],
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> Bool {
        guard !allowsCloud else { return false }
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return false
        }
        if TranscriptionModelRegistry.model(forSelectionKey: key, in: knownModels) != nil {
            return false
        }
        return !key.hasPrefix("Custom:")
    }

    // MARK: - Enhancement

    static func enhancementBlocked(
        _ provider: AIProvider,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> Bool {
        !ProviderPolicy.isAllowed(provider, allowsCloud: allowsCloud)
    }

    /// The provider a mode stores for enhancement, when enhancement is on and this build does
    /// not allow that provider. Resolution drops such a provider (it is never in
    /// `AIService.connectedProviders`), so this reads the stored value.
    static func blockedEnhancementProvider(
        for mode: ModeConfig?,
        allowsCloud: Bool = ProviderPolicy.allowsCloud
    ) -> AIProvider? {
        guard let mode, mode.isAIEnhancementEnabled,
            let rawValue = mode.selectedAIProvider,
            let provider = AIProvider(rawValue: rawValue),
            enhancementBlocked(provider, allowsCloud: allowsCloud)
        else {
            return nil
        }
        return provider
    }

    // MARK: - Presentation

    /// The mode a recording started now would most likely use: the explicit mode, then the
    /// frontmost app's rule, then the default mode. Website rules are applied later by
    /// `ActiveWindowService`, so the engine checks again once the mode is final.
    static func modeForRecordingStart(modeId: UUID?) -> ModeConfig? {
        let modeManager = ModeManager.shared
        if let modeId, let config = modeManager.getConfiguration(with: modeId) {
            return config
        }
        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            let appConfig = modeManager.getConfigurationForApp(bundleIdentifier)
        {
            return appConfig
        }
        return modeManager.getDefaultConfiguration() ?? modeManager.currentEffectiveConfiguration
    }

    static func showBlockedNotice() {
        NotificationManager.shared.showNotification(
            title: String(localized: "Choose an on-device model"),
            type: .error
        )
    }

    /// Recording is blocked: tell the user and open the settings page that can clear the block.
    static func presentBlockedTranscription(route: BlockedTranscriptionRoute) {
        showBlockedNotice()
        switch route {
        case .modes:
            ModeSetupNavigator.openModesSettings()
        case .models:
            ModeSetupNavigator.openModelsSettings()
        }
    }

    /// Shows the notice once per launch when the default mode is blocked.
    static func showLaunchNoticeIfBlocked(transcriptionModelManager: TranscriptionModelManager) {
        guard !didShowLaunchNotice else { return }
        let modeManager = ModeManager.shared
        let defaultMode = modeManager.getDefaultConfiguration() ?? modeManager.currentEffectiveConfiguration
        let isBlocked =
            transcriptionBlocked(mode: defaultMode, transcriptionModelManager: transcriptionModelManager)
            || blockedEnhancementProvider(for: defaultMode) != nil
        guard isBlocked else { return }
        didShowLaunchNotice = true
        showBlockedNotice()
    }
}
