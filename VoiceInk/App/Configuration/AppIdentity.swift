import Foundation

/// ScribeInk's identity on disk, in the Keychain and in the unified log.
///
/// Everything derives from the running bundle's identifier, so ScribeInk installs next to
/// VoiceInk without sharing data, and the `.dev` build gets its own folder and services.
/// Not main-actor isolated: logger and queue initialisers use it from any context.
///
/// The embedded Refine XPC service name is a literal in `Shared/VoiceInkRefineXPCProtocol.swift`,
/// because that file is also compiled into the XPC target, which can't see this type.
enum AppIdentity {
    static let fallbackBundleIdentifier = "com.chartside.ScribeInk"

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
    }

    /// Folder name under `~/Library/Application Support`.
    static var applicationSupportFolderName: String {
        bundleIdentifier
    }

    /// `os.Logger` subsystem; log export filters on it.
    static var loggerSubsystem: String {
        bundleIdentifier.lowercased()
    }

    static func queueLabel(_ suffix: String) -> String {
        "\(loggerSubsystem).\(suffix)"
    }

    static var keychainService: String {
        bundleIdentifier
    }

    static var localKeychainService: String {
        "\(bundleIdentifier).Local"
    }

    static let iCloudContainerIdentifier = "iCloud.com.chartside.ScribeInk"
}
