import Foundation

/// Decides which network hosts the app may talk to in on-device builds.
/// Loopback addresses are always permitted. Any other host must have been
/// explicitly confirmed by the user (stored in UserDefaults), unless the
/// build allows cloud providers.
enum LocalEndpoint {
    static let acceptedHostsKey = "acceptedRemoteHosts"

    /// True when the URL's host is `localhost`, `::1`, or an IPv4 address in 127.0.0.0/8.
    static func isLoopback(_ url: URL) -> Bool {
        guard var host = url.host?.lowercased() else { return false }
        if host.hasPrefix("[") && host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }
        if host == "localhost" || host == "::1" {
            return true
        }
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        var values: [Int] = []
        for octet in octets {
            guard !octet.isEmpty,
                  octet.count <= 3,
                  octet.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                  let value = Int(octet),
                  value <= 255 else {
                return false
            }
            values.append(value)
        }
        return values[0] == 127
    }

    /// Hosts the user has confirmed, all lower-cased.
    static func acceptedHosts(_ defaults: UserDefaults = .standard) -> Set<String> {
        let stored = defaults.stringArray(forKey: acceptedHostsKey) ?? []
        return Set(stored.map { $0.lowercased() })
    }

    /// Records a host the user has confirmed. Stored lower-cased.
    static func accept(host: String, defaults: UserDefaults = .standard) {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        var hosts = acceptedHosts(defaults)
        hosts.insert(normalized)
        defaults.set(hosts.sorted(), forKey: acceptedHostsKey)
    }

    static func isPermitted(
        _ url: URL,
        allowsCloud: Bool = ProviderPolicy.allowsCloud,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if allowsCloud || isLoopback(url) {
            return true
        }
        guard let host = url.host?.lowercased() else { return false }
        return acceptedHosts(defaults).contains(host)
    }

    static func requirePermitted(
        _ url: URL,
        allowsCloud: Bool = ProviderPolicy.allowsCloud,
        defaults: UserDefaults = .standard
    ) throws {
        guard isPermitted(url, allowsCloud: allowsCloud, defaults: defaults) else {
            throw ProviderPolicyError.remoteEndpointNotConfirmed(host: url.host ?? "")
        }
    }
}
