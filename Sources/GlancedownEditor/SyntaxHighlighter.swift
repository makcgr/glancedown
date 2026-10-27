import AppKit
import RenderCore

/// Applies Markdown colouring to a text storage. Attributes are display-only and never reach the saved file.
struct SyntaxHighlighter {
    var fontSize: CGFloat

    private var baseFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    private var boldFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .bold) }
    private var italicFont: NSFont {
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: fontSize) ?? baseFont
    }

    var typingAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.textColor]
    }

    func highlight(_ storage: NSTextStorage, tokens: [MarkdownSyntax.Token]) {
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(typingAttributes, range: fullRange)
        for token in tokens {
            storage.addAttributes(attributes(for: token.kind), range: token.range)
        }
        storage.endEditing()
    }

    private func attributes(for kind: MarkdownSyntax.Kind) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .heading:
            return [.font: boldFont, .foregroundColor: NSColor.controlAccentColor]
        case .strong:
            return [.font: boldFont]
        case .emphasis:
            return [.font: italicFont]
        case .strikethrough:
            return [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: NSColor.secondaryLabelColor]
        case .inlineCode:
            return [.foregroundColor: NSColor.systemPink, .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.15)]
        case .codeBlock:
            return [.foregroundColor: NSColor.secondaryLabelColor, .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12)]
        case .link:
            return [.foregroundColor: NSColor.linkColor]
        case .quote:
            return [.foregroundColor: NSColor.secondaryLabelColor, .font: italicFont]
        case .listMarker:
            return [.foregroundColor: NSColor.systemOrange, .font: boldFont]
        }
    }
}
