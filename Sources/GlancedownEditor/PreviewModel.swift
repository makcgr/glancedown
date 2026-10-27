import AppKit
import RenderCore
import WebKit

/// The live preview pane: renders the unsaved text through RenderCore.
@MainActor
final class PreviewModel {
    let webView: WKWebView
    private let page: DocumentPage
    private let navigation: PreviewNavigation
    private var latestText: String
    private var pendingUpdate: Task<Void, Never>?

    /// Unsaved documents render from a temporary folder, so relative images only work after the first save.
    init(fileURL: URL?, text: String) {
        latestText = text
        let file = fileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("Untitled.md")
        page = DocumentPage(fileURL: file, rootURL: fileURL == nil ? file.deletingLastPathComponent() : nil)
        navigation = PreviewNavigation(page: page)
        webView = PageWebView.make(page: page)
        page.contentProvider = { [weak self] in self?.latestText ?? "" }
        webView.navigationDelegate = navigation
        webView.load(URLRequest(url: page.pageURL))
    }

    func textDidChange(_ text: String) {
        latestText = text
        pendingUpdate?.cancel()
        pendingUpdate = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled, let html = try? self.page.renderBody() else { return }
            await PageWebView.update(self.webView, html: html)
        }
    }

    func scroll(toHeadingIndex index: Int) {
        Task { await PageWebView.scrollToHeading(webView, index: index) }
    }

    func setZoom(_ zoom: Double) {
        webView.pageZoom = zoom
    }
}

/// Links in the preview open outside the editor; the preview itself never navigates away.
private final class PreviewNavigation: NSObject, WKNavigationDelegate {
    private let page: DocumentPage

    init(page: DocumentPage) {
        self.page = page
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        switch page.linkAction(for: url) {
        case .allow:
            decisionHandler(.allow)
        case .openDocument(let file), .openFile(let file), .openExternal(let file):
            decisionHandler(.cancel)
            NSWorkspace.shared.open(file)
        case .ignore:
            decisionHandler(.cancel)
        }
    }
}
