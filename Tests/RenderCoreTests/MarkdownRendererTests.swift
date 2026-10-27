import Testing
@testable import RenderCore

struct MarkdownRendererTests {
    private let renderer = MarkdownRenderer()

    @Test func rendersGitHubTables() {
        let html = renderer.html(from: "| a | b |\n|---|---|\n| 1 | 2 |\n")
        #expect(html.contains("<table>"))
        #expect(html.contains("<td>2</td>"))
    }

    @Test func rendersTaskListsStrikethroughAndAutolinks() {
        let html = renderer.html(from: "- [x] done\n- [ ] todo\n\n~~old~~ https://example.com\n")
        #expect(html.contains("type=\"checkbox\" checked=\"\" disabled=\"\""))
        #expect(html.contains("<del>old</del>"))
        #expect(html.contains("<a href=\"https://example.com\">"))
    }

    @Test func marksFencedCodeWithItsLanguage() {
        let html = renderer.html(from: "```swift\nlet x = 1\n```\n")
        #expect(html.contains("<code class=\"language-swift\">"))
    }

    @Test func rendersFootnotes() {
        let html = renderer.html(from: "Text[^1]\n\n[^1]: Note\n")
        #expect(html.contains("class=\"footnotes\""))
    }

    @Test func dropsRawHTMLByDefault() {
        let html = renderer.html(from: "<script>alert(1)</script>\n\n<img src=x onerror=alert(1)>\n")
        #expect(!html.contains("<script"))
        #expect(!html.contains("onerror"))
    }

    @Test func removesUnsafeLinkSchemes() {
        let html = renderer.html(from: "[a](javascript:alert(1)) [b](file:///etc/passwd)\n")
        #expect(!html.contains("javascript:"))
        #expect(!html.contains("file:"))
    }

    @Test func keepsRawHTMLWhenAllowed() {
        let html = MarkdownRenderer(allowsRawHTML: true).html(from: "<kbd>⌘</kbd>\n")
        #expect(html.contains("<kbd>⌘</kbd>"))
    }
}

struct DisplayMathTests {
    @Test func fencesMultiLineDisplayMathAndKeepsBackslashes() {
        let html = MarkdownRenderer().html(from: "$$\n\\int x \\, dx\n$$\n")
        #expect(html.contains("<code class=\"language-math\">\\int x \\, dx\n</code>"))
    }

    @Test func fencesSingleLineDisplayMath() {
        let fenced = MarkdownRenderer.fencingDisplayMath(in: "$$a \\, b$$")
        #expect(fenced == "```math\na \\, b\n```")
    }

    @Test func leavesDollarsInsideCodeFencesAlone() {
        let source = "```bash\n$$\necho hi\n$$\n```"
        #expect(MarkdownRenderer.fencingDisplayMath(in: source) == source)
    }

    @Test func leavesAnUnclosedBlockAsWritten() {
        let source = "$$\nx = 1\nno end"
        #expect(MarkdownRenderer.fencingDisplayMath(in: source) == source)
    }
}
