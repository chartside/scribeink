import Foundation

/// URLSession delegate that follows an HTTP redirect only when the target is a permitted
/// endpoint (`LocalEndpoint.isPermitted`). Otherwise the redirect is refused and the 3xx
/// response is returned to the caller. This keeps a permitted endpoint from forwarding
/// audio to an unconfirmed host. Cloud builds permit every host, so they behave as before.
final class PermittedRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let allowsCloud: Bool
    private let defaults: UserDefaults

    init(allowsCloud: Bool = ProviderPolicy.allowsCloud, defaults: UserDefaults = .standard) {
        self.allowsCloud = allowsCloud
        self.defaults = defaults
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
            LocalEndpoint.isPermitted(url, allowsCloud: allowsCloud, defaults: defaults)
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
