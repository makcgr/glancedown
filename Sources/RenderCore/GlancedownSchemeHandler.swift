import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves `glancedown://asset/...` from the bundled Web folder and `glancedown://doc/...` from the document's root.
final class GlancedownSchemeHandler: NSObject, WKURLSchemeHandler {
    private let page: DocumentPage

    init(page: DocumentPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        do {
            let (data, mimeType) = try response(for: url)
            let headers = [
                "Content-Type": mimeType,
                "Content-Length": String(data.count),
                "Cache-Control": "no-store",
            ]
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

    private func response(for url: URL) throws -> (Data, String) {
        let path = url.path(percentEncoded: false)
        switch url.host {
        case DocumentPage.documentHost where path == page.pageURL.path(percentEncoded: false):
            return (Data(try page.renderPage().utf8), "text/html; charset=utf-8")
        case DocumentPage.documentHost:
            guard let file = page.localFile(forPath: path) else { throw URLError(.noPermissionsToReadFile) }
            return (try Data(contentsOf: file), Self.mimeType(for: file))
        case DocumentPage.assetHost:
            guard let file = WebResources.url(for: path) else { throw URLError(.fileDoesNotExist) }
            return (try Data(contentsOf: file), Self.mimeType(for: file))
        default:
            throw URLError(.unsupportedURL)
        }
    }

    private static func mimeType(for file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "js": return "text/javascript"
        case "css": return "text/css"
        case "svg": return "image/svg+xml"
        default:
            return UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}
