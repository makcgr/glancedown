import AppKit
import QuickLookUI
import RenderCore
import WebKit

/// Quick Look preview for Markdown files. The sandbox only allows reading the previewed file itself.
@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView?
    private var loadDelegate: LoadDelegate?

    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let page = DocumentPage(fileURL: url, rootURL: url.deletingLastPathComponent())
        let webView = PageWebView.make(page: page)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let delegate = LoadDelegate(page: page, completion: handler)
        webView.navigationDelegate = delegate
        self.webView = webView
        self.loadDelegate = delegate
        webView.load(URLRequest(url: page.pageURL))
    }
}

/// Reports completion to Quick Look once the page has loaded, and blocks navigation away from it.
private final class LoadDelegate: NSObject, WKNavigationDelegate {
    private let page: DocumentPage
    private var completion: ((Error?) -> Void)?

    init(page: DocumentPage, completion: @escaping (Error?) -> Void) {
        self.page = page
        self.completion = completion
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let isOwnPage = navigationAction.request.url.map { page.linkAction(for: $0) == .allow } ?? false
        decisionHandler(isOwnPage ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    private func finish(_ error: Error?) {
        completion?(error)
        completion = nil
    }
}
