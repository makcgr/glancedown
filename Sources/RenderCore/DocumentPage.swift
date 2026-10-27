import Foundation

/// What the viewer should do when the page navigates to a URL.
public enum LinkAction: Equatable {
    case allow
    case openDocument(URL)
    case openFile(URL)
    case openExternal(URL)
    case ignore
}

/// One Markdown file as a web page: its URL inside the `glancedown://` scheme and its rendered HTML.
public final class DocumentPage {
    public static let scheme = "glancedown"
    static let documentHost = "doc"
    static let assetHost = "asset"

    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn"]
    private static let externalSchemes: Set<String> = ["http", "https", "mailto"]

    public let fileURL: URL
    /// Local files are served only from inside this folder.
    public let rootURL: URL
    public let pageURL: URL
    public var renderer: MarkdownRenderer

    public init(fileURL: URL, rootURL: URL? = nil, renderer: MarkdownRenderer = MarkdownRenderer()) {
        let file = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        let root = (rootURL ?? Self.projectRoot(containing: file)).standardizedFileURL.resolvingSymlinksInPath()
        self.fileURL = file
        self.rootURL = root
        self.renderer = renderer

        let relativePath = String(file.path.dropFirst(root.path.count + 1))
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.documentHost
        components.path = "/" + relativePath
        self.pageURL = components.url!
    }

    /// The nearest folder above the file that holds a `.git` entry, so `../images/x.png` works inside a repo.
    public static func projectRoot(containing file: URL) -> URL {
        let folder = file.deletingLastPathComponent()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        var candidate = folder
        while candidate.path != "/" && candidate.path != home {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent(".git").path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        return folder
    }

    public func renderBody() throws -> String {
        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        return renderer.html(from: text)
    }

    public func renderPage() throws -> String {
        let template = try String(contentsOf: WebResources.directory.appendingPathComponent("index.html"), encoding: .utf8)
        let body = try renderBody()
        return template
            .replacingOccurrences(of: "{{TITLE}}", with: Self.escapeHTML(fileURL.lastPathComponent))
            .replacingOccurrences(of: "{{CONTENT}}", with: body)
    }

    /// Maps a `glancedown://doc/...` path to a file under `rootURL`, or nil when it would leave the root.
    public func localFile(forPath path: String) -> URL? {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !relative.isEmpty else { return nil }
        let candidate = rootURL.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(rootURL.path + "/") else { return nil }
        return candidate
    }

    public func linkAction(for url: URL) -> LinkAction {
        guard let scheme = url.scheme?.lowercased() else { return .ignore }

        if scheme == Self.scheme {
            guard url.host == Self.documentHost else { return .ignore }
            let path = url.path(percentEncoded: false)
            if path == pageURL.path(percentEncoded: false) {
                return .allow
            }
            guard let file = localFile(forPath: path) else { return .ignore }
            if Self.markdownExtensions.contains(file.pathExtension.lowercased()) {
                return .openDocument(file)
            }
            return .openFile(file)
        }

        if Self.externalSchemes.contains(scheme) {
            return .openExternal(url)
        }
        return .ignore
    }

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
