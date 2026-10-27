import Foundation
import Testing
@testable import RenderCore

struct DocumentPageTests {
    private let root: URL
    private let page: DocumentPage

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("glancedown-tests-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "# Title\n".write(to: docs.appendingPathComponent("read me.md"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("logo.png"), atomically: true, encoding: .utf8)
        page = DocumentPage(fileURL: docs.appendingPathComponent("read me.md"))
    }

    @Test func usesTheRepositoryFolderAsRoot() {
        #expect(page.rootURL.lastPathComponent == root.lastPathComponent)
        #expect(page.pageURL.absoluteString == "glancedown://doc/docs/read%20me.md")
    }

    @Test func servesFilesInsideTheRoot() {
        #expect(page.localFile(forPath: "/logo.png")?.lastPathComponent == "logo.png")
    }

    @Test func refusesPathsThatLeaveTheRoot() {
        #expect(page.localFile(forPath: "/../../etc/hosts") == nil)
        #expect(page.localFile(forPath: "/") == nil)
    }

    @Test func refusesSymlinksThatPointOutsideTheRoot() throws {
        let link = root.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/etc"))
        #expect(page.localFile(forPath: "/escape/hosts") == nil)
    }

    @Test func allowsTheOwnPageAndItsFragments() {
        #expect(page.linkAction(for: URL(string: "glancedown://doc/docs/read%20me.md#title")!) == .allow)
    }

    @Test func opensOtherMarkdownFilesAsDocuments() {
        let action = page.linkAction(for: URL(string: "glancedown://doc/docs/other.md")!)
        guard case .openDocument(let file) = action else {
            Issue.record("expected openDocument, got \(action)")
            return
        }
        #expect(file.lastPathComponent == "other.md")
    }

    @Test func sendsWebLinksToTheBrowserAndIgnoresTheRest() {
        let web = URL(string: "https://example.com")!
        #expect(page.linkAction(for: web) == .openExternal(web))
        #expect(page.linkAction(for: URL(string: "file:///etc/passwd")!) == .ignore)
        #expect(page.linkAction(for: URL(string: "glancedown://asset/app.js")!) == .ignore)
    }

    @Test func embedsEscapedTitleAndContentInTheTemplate() throws {
        let html = try page.renderPage()
        #expect(html.contains("<title>read me.md</title>"))
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("Content-Security-Policy"))
    }
}

struct ContentProviderTests {
    @Test func rendersUnsavedTextInsteadOfTheFile() throws {
        let page = DocumentPage(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("Untitled.md"),
            rootURL: FileManager.default.temporaryDirectory
        )
        page.contentProvider = { "# Draft" }
        #expect(try page.renderBody().contains("<h1>Draft</h1>"))
    }
}
