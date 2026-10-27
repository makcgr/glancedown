import AppKit
import WebKit

/// A heading reported by the page, used for the outline sidebar.
public struct OutlineItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
}

/// Messages the page script sends to the native side.
public enum PageMessage: Equatable {
    case outline([OutlineItem])
    case activeHeading(String?)
    case reloadRequested

    static let handlerName = "glancedown"

    /// Accepts only the expected shapes; anything else is dropped.
    init?(body: Any) {
        guard let dictionary = body as? [String: Any], let type = dictionary["type"] as? String else { return nil }
        switch type {
        case "outline":
            guard let rawItems = dictionary["items"] as? [[String: Any]] else { return nil }
            let items = rawItems.prefix(2000).compactMap { raw -> OutlineItem? in
                guard let id = raw["id"] as? String,
                      let level = raw["level"] as? Int, (1...6).contains(level),
                      let title = raw["title"] as? String
                else { return nil }
                return OutlineItem(id: id, level: level, title: String(title.prefix(300)))
            }
            self = .outline(items)
        case "active":
            self = .activeHeading(dictionary["id"] as? String)
        case "reload":
            self = .reloadRequested
        default:
            return nil
        }
    }
}

@MainActor
public enum PageWebView {
    /// Builds a web view wired to serve `page`. `onMessage` receives outline updates from the page script.
    public static func make(page: DocumentPage, onMessage: ((PageMessage) -> Void)? = nil) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(GlancedownSchemeHandler(page: page), forURLScheme: DocumentPage.scheme)
        if let onMessage {
            configuration.userContentController.add(MessageRelay(onMessage), name: PageMessage.handlerName)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = .textBackgroundColor
        return webView
    }

    /// Replaces the article body in place, so scroll position and loaded scripts survive.
    public static func update(_ webView: WKWebView, html: String) async {
        _ = try? await webView.callAsyncJavaScript(
            "window.glancedown && window.glancedown.update(html)",
            arguments: ["html": html],
            contentWorld: .page
        )
    }

    public static func scrollToHeading(_ webView: WKWebView, index: Int) async {
        _ = try? await webView.callAsyncJavaScript(
            "window.glancedown && window.glancedown.scrollToHeadingIndex(index)",
            arguments: ["index": index],
            contentWorld: .page
        )
    }

    public static func scrollToHeading(_ webView: WKWebView, id: String) async {
        _ = try? await webView.callAsyncJavaScript(
            "window.glancedown && window.glancedown.scrollToHeading(id)",
            arguments: ["id": id],
            contentWorld: .page
        )
    }
}

/// WKUserContentController retains its handlers, so callers must capture their owner weakly in `onMessage`.
private final class MessageRelay: NSObject, WKScriptMessageHandler {
    private let onMessage: (PageMessage) -> Void

    init(_ onMessage: @escaping (PageMessage) -> Void) {
        self.onMessage = onMessage
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let parsed = PageMessage(body: message.body) {
            onMessage(parsed)
        }
    }
}
