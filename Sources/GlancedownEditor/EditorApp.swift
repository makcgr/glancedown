import SwiftUI

@main
struct EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownText()) { file in
            EditorView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            EditorCommands()
        }
    }
}
