import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Converts GitHub-flavored Markdown to an HTML fragment.
public struct MarkdownRenderer: Sendable {
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]

    /// When false, raw HTML in the source is dropped and unsafe link schemes are removed.
    public var allowsRawHTML: Bool

    public init(allowsRawHTML: Bool = false) {
        self.allowsRawHTML = allowsRawHTML
    }

    public func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        var options = CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES
        if allowsRawHTML {
            options |= CMARK_OPT_UNSAFE
        }

        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in Self.extensionNames {
            if let syntaxExtension = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }

        var source = Self.fencingDisplayMath(in: markdown)
        source.withUTF8 { buffer in
            buffer.withMemoryRebound(to: CChar.self) { chars in
                cmark_parser_feed(parser, chars.baseAddress, chars.count)
            }
        }

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else {
            return ""
        }
        defer { free(rendered) }
        return String(cString: rendered)
    }

    /// Turns `$$ … $$` blocks that start a line into ```math fences, so cmark keeps backslashes such as `\,` intact.
    static func fencingDisplayMath(in markdown: String) -> String {
        var output: [Substring] = []
        var codeFence: Substring?
        var mathIndent: Substring = ""
        var mathLines: [Substring]?
        var originalMathLines: [Substring] = []

        func emitMath(_ body: [Substring]) {
            output.append(mathIndent + "```math")
            output.append(contentsOf: body)
            output.append(mathIndent + "```")
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" })
            let trimmed = line.dropFirst(indent.count)

            if var body = mathLines {
                originalMathLines.append(line)
                if trimmed.hasSuffix("$$") {
                    let last = trimmed.dropLast(2)
                    if !last.allSatisfy(\.isWhitespace) { body.append(last) }
                    emitMath(body)
                    mathLines = nil
                } else {
                    body.append(line)
                    mathLines = body
                }
                continue
            }

            if let fence = codeFence {
                if trimmed.hasPrefix(fence) { codeFence = nil }
                output.append(line)
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                codeFence = trimmed.prefix(while: { $0 == trimmed.first })
                output.append(line)
                continue
            }

            if trimmed.hasPrefix("$$") {
                let rest = trimmed.dropFirst(2)
                mathIndent = indent
                if rest.count >= 2, rest.hasSuffix("$$") {
                    emitMath([rest.dropLast(2)])
                } else {
                    mathLines = rest.allSatisfy(\.isWhitespace) ? [] : [rest]
                    originalMathLines = [line]
                }
                continue
            }

            output.append(line)
        }

        // An unclosed block is left exactly as written.
        if mathLines != nil {
            output.append(contentsOf: originalMathLines)
        }
        return output.joined(separator: "\n")
    }
}
