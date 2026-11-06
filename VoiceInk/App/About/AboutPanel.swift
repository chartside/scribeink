import AppKit

/// The standard macOS About panel with ScribeInk's GPL attribution, update status and support link.
enum AboutPanel {
    static let upstreamURL = URL(string: "https://github.com/Beingpax/VoiceInk")!

    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits()
        ])
    }

    static func credits() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let result = NSMutableAttributedString()

        let attribution = "ScribeInk is based on VoiceInk by Prakash Joshi Pax, licensed under GPL v3"
        var linked = base
        linked[.link] = upstreamURL
        result.append(NSAttributedString(string: attribution, attributes: linked))

        result.append(NSAttributedString(
            string: "\n" + String(localized: "Updates are not available yet.") + "\n",
            attributes: base))

        var support = base
        support[.link] = UpstreamServices.supportURL
        result.append(NSAttributedString(string: UpstreamServices.supportURL.absoluteString, attributes: support))

        return result
    }
}
