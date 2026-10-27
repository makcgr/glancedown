import AppKit
import Observation
import RenderCore
import WebKit

/// State for one open document window: the page, its web view, the outline and find.
@MainActor
@Observable
final class DocumentModel {
    let fileURL: URL
    var outline: [OutlineItem] = []
    var activeHeadingID: String?
    var isFindBarVisible = false
    var findText = ""
    var findHasNoMatch = false

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let page: DocumentPage
    @ObservationIgnored private let navigation = NavigationHandler()
    @ObservationIgnored private var watcher: FileWatcher?

    init(fileURL: URL) {
        self.fileURL = fileURL
        let page = DocumentPage(fileURL: fileURL)
        self.page = page

        weak var weakSelf: DocumentModel?
        webView = PageWebView.make(page: page) { message in
            weakSelf?.handle(message)
        }
        weakSelf = self

        navigation.page = page
        webView.navigationDelegate = navigation
        webView.load(URLRequest(url: page.pageURL))
        watcher = FileWatcher(url: page.fileURL) { [weak self] in
            self?.reload()
        }
    }

    func reload() {
        guard let html = try? page.renderBody() else { return }
        Task { await PageWebView.update(webView, html: html) }
    }

    func scroll(to item: OutlineItem) {
        Task { await PageWebView.scrollToHeading(webView, id: item.id) }
    }

    func setZoom(_ zoom: Double) {
        webView.pageZoom = zoom
    }

    func find(backwards: Bool = false) {
        guard !findText.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(findText, configuration: configuration) { [weak self] result in
            self?.findHasNoMatch = !result.matchFound
        }
    }

    func showFindBar() {
        isFindBarVisible = true
    }

    func hideFindBar() {
        isFindBarVisible = false
        findHasNoMatch = false
        webView.window?.makeFirstResponder(webView)
    }

    func print() {
        guard let window = webView.window else { return }
        let operation = webView.printOperation(with: NSPrintInfo.shared)
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func openInEditor() {
        EditorLauncher.open(fileURL)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func handle(_ message: PageMessage) {
        switch message {
        case .outline(let items):
            outline = items
        case .activeHeading(let id):
            activeHeadingID = id
        case .reloadRequested:
            webView.reload()
        }
    }
}

/// Keeps the page on its own document; other links open in the app or browser that owns them.
private final class NavigationHandler: NSObject, WKNavigationDelegate {
    var page: DocumentPage?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let page else {
            decisionHandler(.cancel)
            return
        }
        switch page.linkAction(for: url) {
        case .allow:
            decisionHandler(.allow)
        case .openDocument(let file):
            decisionHandler(.cancel)
            NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { _, _, _ in }
        case .openFile(let file), .openExternal(let file):
            decisionHandler(.cancel)
            NSWorkspace.shared.open(file)
        case .ignore:
            decisionHandler(.cancel)
        }
    }
}
