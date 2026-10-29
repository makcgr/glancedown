import AppKit
import Testing
@testable import GlancedownEditor

@MainActor
struct MarkdownDocumentTests {
    private let type = "net.daringfireball.markdown"

    init() {
        _ = NSApplication.shared
    }

    // Classic saving: with autosave off, AppKit asks "Save changes?" on close and quit.
    @Test func doesNotAutosave() {
        #expect(MarkdownDocument.autosavesInPlace == false)
    }

    @Test func savesTheTextItRead() throws {
        let document = MarkdownDocument()
        try document.read(from: Data("# Привет\n".utf8), ofType: type)

        #expect(try document.data(ofType: type) == Data("# Привет\n".utf8))
    }

    // Typing must reach the document's undo manager, or the document never counts as changed.
    @Test func typingMarksTheDocumentChangedAndUndoClearsIt() throws {
        let document = MarkdownDocument()
        try document.read(from: Data("# Title\n".utf8), ofType: type)
        document.makeWindowControllers()
        let window = try #require(document.windowControllers.first?.window)
        window.contentView?.layoutSubtreeIfNeeded()
        let textView = try #require(findTextView(in: window.contentView))
        #expect(document.isDocumentEdited == false)

        textView.insertText("more", replacementRange: NSRange(location: 8, length: 0))
        settle()

        #expect(document.isDocumentEdited)
        #expect(document.state.text == "# Title\nmore")

        document.undoManager?.undo()
        settle()

        #expect(document.isDocumentEdited == false)
        #expect(textView.string == "# Title\n")
        #expect(document.state.text == "# Title\n")
        document.close()
    }

    // Colouring runs after the edit, so a line that becomes a heading gets the heading colour.
    @Test func colorsTextTypedAfterOpening() throws {
        let document = MarkdownDocument()
        try document.read(from: Data("text\n".utf8), ofType: type)
        document.makeWindowControllers()
        let window = try #require(document.windowControllers.first?.window)
        window.contentView?.layoutSubtreeIfNeeded()
        let textView = try #require(findTextView(in: window.contentView))

        textView.insertText("## New", replacementRange: NSRange(location: 5, length: 0))
        settle()

        let color = textView.textStorage?.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor
        #expect(color == NSColor.controlAccentColor)
        document.close()
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        return view.subviews.lazy.compactMap(findTextView).first
    }
}
