import AppKit
import Foundation

/// ScribeInk has no support email address yet, so support requests go to the
/// project page (`UpstreamServices.supportURL`) in the browser. The system
/// information is copied to the clipboard so it can be pasted into the request.
@MainActor
struct EmailSupport {
    static func openSupportEmail() {
        SystemInfoService.shared.copySystemInfoToClipboard()
        NSWorkspace.shared.open(UpstreamServices.supportURL)
    }
}
