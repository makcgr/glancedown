import Foundation
import Testing
@testable import RenderCore

struct MarkdownSyntaxTests {
    private func kinds(_ text: String) -> [MarkdownSyntax.Kind] {
        MarkdownSyntax.tokens(in: text).map(\.kind)
    }

    @Test func findsHeadingsWithTheirLevel() {
        #expect(kinds("## Title") == [.heading(level: 2)])
        #expect(kinds("#hashtag").isEmpty)
    }

    @Test func treatsEverythingInsideAFenceAsCode() {
        let tokens = kinds("```\n# not a heading\n**not bold**\n```\n**bold**")
        #expect(tokens == [.codeBlock, .codeBlock, .codeBlock, .codeBlock, .strong])
    }

    @Test func findsInlineSpans() {
        let tokens = kinds("a **b** *c* `d` [e](f) ~~g~~")
        #expect(tokens.contains(.strong))
        #expect(tokens.contains(.emphasis))
        #expect(tokens.contains(.inlineCode))
        #expect(tokens.contains(.link))
        #expect(tokens.contains(.strikethrough))
    }

    @Test func doesNotTreatStrongMarkersAsEmphasis() {
        #expect(!kinds("**bold**").contains(.emphasis))
        #expect(!kinds("snake_case_name").contains(.emphasis))
    }

    @Test func marksListMarkersAndQuotes() {
        #expect(kinds("- item") == [.listMarker])
        #expect(kinds("12. item") == [.listMarker])
        #expect(kinds("> quote") == [.quote])
    }

    @Test func countsHeadingsUpToAnOffset() {
        let text = "intro\n# One\ntext\n```\n# fenced\n```\n## Two\nend"
        #expect(MarkdownSyntax.headingIndex(in: text, atOffset: 0) == -1)
        #expect(MarkdownSyntax.headingIndex(in: text, atOffset: 7) == 0)
        #expect(MarkdownSyntax.headingIndex(in: text, atOffset: (text as NSString).length) == 1)
    }
}
