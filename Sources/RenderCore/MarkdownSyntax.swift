import Foundation

/// A light, line-based Markdown tokenizer for editor syntax colouring. It favours speed over full CommonMark accuracy.
public enum MarkdownSyntax {
    public enum Kind: Equatable, Sendable {
        case heading(level: Int)
        case codeBlock
        case inlineCode
        case strong
        case emphasis
        case strikethrough
        case link
        case quote
        case listMarker
    }

    public struct Token: Equatable, Sendable {
        public let range: NSRange
        public let kind: Kind
    }

    private static let heading = try! NSRegularExpression(pattern: "^ {0,3}(#{1,6})(?:[ \\t]|$)")
    private static let quote = try! NSRegularExpression(pattern: "^ {0,3}>")
    private static let listMarker = try! NSRegularExpression(pattern: "^[ \\t]*(?:[-*+]|\\d{1,9}[.)])(?=[ \\t])")
    private static let inlinePatterns: [(NSRegularExpression, Kind)] = [
        (try! NSRegularExpression(pattern: "!?\\[[^\\]\\n]*\\]\\([^)\\n]*\\)"), .link),
        (try! NSRegularExpression(pattern: "~~[^~\\n]+~~"), .strikethrough),
        (try! NSRegularExpression(pattern: "(?<![*\\w])\\*(?![\\s*])[^*\\n]*?[^\\s*]\\*(?!\\*)|(?<![_\\w])_(?![\\s_])[^_\\n]*?[^\\s_]_(?![_\\w])"), .emphasis),
        (try! NSRegularExpression(pattern: "\\*\\*(?!\\s)[^*\\n]+?\\*\\*|__(?!\\s)[^_\\n]+?__"), .strong),
        (try! NSRegularExpression(pattern: "`[^`\\n]+`"), .inlineCode),
    ]

    /// Tokens in paint order: later tokens win where they overlap.
    public static func tokens(in text: String) -> [Token] {
        let string = text as NSString
        var tokens: [Token] = []
        var fence: String?

        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = string.substring(with: lineRange)
            let trimmed = line.drop(while: { $0 == " " })

            if let open = fence {
                tokens.append(Token(range: lineRange, kind: .codeBlock))
                if trimmed.hasPrefix(open) { fence = nil }
                return
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(while: { $0 == trimmed.first }))
                tokens.append(Token(range: lineRange, kind: .codeBlock))
                return
            }

            let local = NSRange(location: 0, length: lineRange.length)
            if let match = heading.firstMatch(in: line, range: local) {
                tokens.append(Token(range: lineRange, kind: .heading(level: match.range(at: 1).length)))
            } else if quote.firstMatch(in: line, range: local) != nil {
                tokens.append(Token(range: lineRange, kind: .quote))
            } else if let match = listMarker.firstMatch(in: line, range: local) {
                tokens.append(Token(range: NSRange(location: lineRange.location + match.range.location, length: match.range.length), kind: .listMarker))
            }

            for (pattern, kind) in inlinePatterns {
                for match in pattern.matches(in: line, range: local) {
                    tokens.append(Token(range: NSRange(location: lineRange.location + match.range.location, length: match.range.length), kind: kind))
                }
            }
        }
        return tokens
    }

    /// Index of the last ATX heading that starts at or before `offset` (UTF-16), or -1 when there is none.
    public static func headingIndex(in text: String, atOffset offset: Int) -> Int {
        var index = -1
        for token in tokens(in: text) {
            guard case .heading = token.kind else { continue }
            if token.range.location > offset { break }
            index += 1
        }
        return index
    }
}
