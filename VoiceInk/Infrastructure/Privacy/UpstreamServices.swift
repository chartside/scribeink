import Foundation

/// The single place that decides which upstream VoiceInk services ScribeInk
/// uses. ScribeInk is a separate install: it does not update from, license
/// through, take announcements from, or promote the upstream project. Every
/// flag is off, so the gated code stays in the tree (for upstream merges) but
/// never runs and makes no network call. ScribeInk's own updates, licensing
/// and announcements replace these later.
enum UpstreamServices {
    /// Sparkle updates from the upstream appcast. Off: the updater is never
    /// created or started and "Check for Updates" is hidden.
    static let updatesEnabled: Bool = false

    /// Upstream licensing and trial (Polar). Off: the app behaves as fully
    /// licensed, shows no licence or trial UI and makes no licence call.
    static let licensingEnabled: Bool = false

    /// Remote in-app announcements from the upstream site. Off: never fetched.
    static let announcementsEnabled: Bool = false

    /// The prompt asking the user to star the upstream GitHub repository.
    static let starPromptEnabled: Bool = false

    /// Where support and "learn more" links go until ScribeInk has its own site.
    static let supportURL = URL(string: "https://github.com/chartside/scribeink")!
}
