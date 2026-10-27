import SwiftUI

@main
struct GlancedownApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownFile.self) { file in
            DocumentView(fileURL: file.fileURL)
        }
        .commands {
            ViewerCommands()
        }
    }
}
