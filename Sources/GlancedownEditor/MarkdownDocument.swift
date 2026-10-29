import AppKit
import Observation
import SwiftUI

/// The text and location of one open document, observed by its editor window.
@Observable
final class EditorState {
    var text = ""
    var fileURL: URL?
}

/// A Markdown file with classic saving: no autosave, and closing or quitting with changes asks first.
@objc(MarkdownDocument)
final class MarkdownDocument: NSDocument {
    let state = EditorState()
    let controller = EditorController()

    override class var autosavesInPlace: Bool { false }

    override var fileURL: URL? {
        didSet { state.fileURL = fileURL }
    }

    override var shouldRunSavePanelWithAccessoryView: Bool { false }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        state.text = String(decoding: data, as: UTF8.self)
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(state.text.utf8)
    }

    @objc func formatBold(_ sender: Any?) { controller.wrapSelection("**") }
    @objc func formatItalic(_ sender: Any?) { controller.wrapSelection("*") }
    @objc func formatStrikethrough(_ sender: Any?) { controller.wrapSelection("~~") }
    @objc func formatInlineCode(_ sender: Any?) { controller.wrapSelection("`") }
    @objc func formatLink(_ sender: Any?) { controller.insertLink() }
}

/// Hosts the SwiftUI editor and routes the text view's undo to the document, which marks it as changed.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    init(document: MarkdownDocument) {
        let hosting = NSHostingController(rootView: EditorView(state: document.state, controller: document.controller))
        hosting.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1100, height: 720))
        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = true
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        document?.undoManager
    }
}
