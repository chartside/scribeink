import SwiftUI

/// Pure decisions behind the remote-endpoint warning. No UI, so it can be unit tested.
enum RemoteEndpointConfirmation {
    /// The host to warn about before saving or probing `urlString`, or nil when no warning
    /// is needed: the build allows cloud providers (upstream behaviour, as in
    /// `LocalEndpoint.isPermitted`), the host is loopback, the user has already accepted it,
    /// or the string is not a URL with a host (dispatch refuses those later, so there is
    /// nothing to confirm).
    static func hostNeedingConfirmation(
        for urlString: String,
        allowsCloud: Bool = ProviderPolicy.allowsCloud,
        defaults: UserDefaults = .standard
    ) -> String? {
        guard let host = remoteHost(for: urlString, allowsCloud: allowsCloud) else { return nil }
        return LocalEndpoint.acceptedHosts(defaults).contains(host) ? nil : host
    }

    /// The lower-cased host of `urlString` when it is a URL with a non-loopback host,
    /// accepted or not. Nil for loopback, empty or malformed strings, and always nil in
    /// builds that allow cloud providers.
    static func remoteHost(for urlString: String, allowsCloud: Bool = ProviderPolicy.allowsCloud) -> String? {
        guard !allowsCloud else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let host = url.host?.lowercased(),
            !host.isEmpty,
            !LocalEndpoint.isLoopback(url)
        else {
            return nil
        }
        return host
    }

    static func warningMessage(host: String) -> String {
        String(
            format: String(
                localized:
                    "This sends audio or transcripts containing patient information to %@. Only use a server you control inside your clinic."
            ),
            host
        )
    }

    static func remoteLabel(host: String) -> String {
        String(format: String(localized: "Remote: %@"), host)
    }
}

/// What the user was doing when a confirmation was requested, for views that ask before
/// both saving and testing an endpoint.
enum RemoteEndpointAction {
    case save
    case testConnection
}

private struct RemoteEndpointConfirmationModifier: ViewModifier {
    @Binding var urlString: String
    @Binding var pendingHost: String?
    let revertTo: String?
    let onConfirmed: () -> Void
    let onCancelled: () -> Void

    private var isPresented: Binding<Bool> {
        Binding(
            get: { pendingHost != nil },
            set: { newValue in
                if !newValue {
                    pendingHost = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content.alert(
            Text(String(localized: "Use a remote server?")),
            isPresented: isPresented,
            presenting: pendingHost
        ) { host in
            Button(String(localized: "Cancel"), role: .cancel) {
                if let revertTo {
                    urlString = revertTo
                }
                pendingHost = nil
                onCancelled()
            }
            Button(String(localized: "Continue")) {
                LocalEndpoint.accept(host: host)
                pendingHost = nil
                onConfirmed()
            }
        } message: { host in
            Text(RemoteEndpointConfirmation.warningMessage(host: host))
        }
    }
}

extension View {
    /// Shows the remote-endpoint warning while `pendingHost` is non-nil.
    ///
    /// The caller sets `pendingHost` to `RemoteEndpointConfirmation.hostNeedingConfirmation(for:)`
    /// when the user saves (or tests) an endpoint, and performs the action directly when that
    /// returns nil. Continue records the host as accepted, then calls `onConfirmed`, which
    /// performs the original action. Cancel puts `revertTo` (the previously saved value) back
    /// into `urlString` when it is non-nil, then calls `onCancelled`.
    func remoteEndpointConfirmation(
        urlString: Binding<String>,
        pendingHost: Binding<String?>,
        revertTo: String?,
        onConfirmed: @escaping () -> Void,
        onCancelled: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            RemoteEndpointConfirmationModifier(
                urlString: urlString,
                pendingHost: pendingHost,
                revertTo: revertTo,
                onConfirmed: onConfirmed,
                onCancelled: onCancelled
            )
        )
    }
}

/// "Remote: {host}" for a non-loopback endpoint. Renders nothing for loopback or
/// malformed URLs, or in builds that allow cloud providers.
struct RemoteEndpointBadge: View {
    let urlString: String

    var body: some View {
        if let host = RemoteEndpointConfirmation.remoteHost(for: urlString) {
            Text(RemoteEndpointConfirmation.remoteLabel(host: host))
                .font(.caption)
                .foregroundStyle(AppTheme.Text.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Surface.subtle)
                )
                .help(RemoteEndpointConfirmation.remoteLabel(host: host))
        }
    }
}
