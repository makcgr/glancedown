import AppKit
import RenderCore
import SwiftUI

/// Gives menu commands access to the focused editor's text view.
@MainActor
final class EditorController {
    weak var textView: NSTextView?

    func wrapSelection(_ prefix: String, _ suffix: String? = nil) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)
        textView.insertText(prefix + selected + (suffix ?? prefix), replacementRange: range)
        textView.setSelectedRange(NSRange(location: range.location + (prefix as NSString).length, length: (selected as NSString).length))
    }

    func insertLink() {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)
        let title = selected.isEmpty ? "title" : selected
        textView.insertText("[\(title)](https://)", replacementRange: range)
        let urlStart = range.location + (title as NSString).length + 3
        textView.setSelectedRange(NSRange(location: urlStart, length: 8))
    }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    let controller: EditorController
    /// Called with the index of the heading at the top of the visible area (-1 before the first heading).
    var onTopHeadingChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.visibleAreaChanged),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        controller.textView = textView
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(fontSize: fontSize)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.applyHighlighting(fontSize: fontSize)
        } else if context.coordinator.fontSize != fontSize {
            context.coordinator.applyHighlighting(fontSize: fontSize)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var textView: NSTextView?
        private(set) var fontSize: CGFloat = 0
        private var lastHeadingIndex: Int?
        private var headingOffsets: [Int] = []
        private var pendingHighlight: DispatchWorkItem?
        /// Above this size (UTF-16 units) a full re-highlight takes long enough to lag typing, so it waits for a pause.
        private let immediateHighlightLimit = 100_000

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }

        func applyHighlighting(fontSize: CGFloat) {
            guard let textView, let storage = textView.textStorage else { return }
            self.fontSize = fontSize
            let tokens = MarkdownSyntax.tokens(in: storage.string)
            headingOffsets = tokens.compactMap { token in
                if case .heading = token.kind { return token.range.location }
                return nil
            }
            let highlighter = SyntaxHighlighter(fontSize: fontSize)
            highlighter.highlight(storage, tokens: tokens)
            textView.typingAttributes = highlighter.typingAttributes
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            pendingHighlight?.cancel()
            guard textView.string.utf16.count > immediateHighlightLimit else {
                applyHighlighting(fontSize: fontSize)
                return
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyHighlighting(fontSize: self.fontSize)
            }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }

        @objc func visibleAreaChanged() {
            guard let textView, let layoutManager = textView.textLayoutManager,
                  let scrollView = textView.enclosingScrollView else { return }
            let top = scrollView.contentView.bounds.minY - textView.textContainerOrigin.y + 4
            guard let fragment = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: max(top, 0))) else { return }
            let offset = layoutManager.offset(from: layoutManager.documentRange.location, to: fragment.rangeInElement.location)
            let index = headingOffsets.lastIndex(where: { $0 <= offset }) ?? -1
            if index != lastHeadingIndex {
                lastHeadingIndex = index
                parent.onTopHeadingChange(index)
            }
        }
    }
}
