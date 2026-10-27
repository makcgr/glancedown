import SwiftUI
import WebKit

enum EditorSettings {
    static let fontSizeKey = "editorFontSize"
    static let defaultFontSize = 13.0
    static let fontSizeRange = 9.0...32.0
    static let showPreviewKey = "showPreview"
}

struct EditorView: View {
    @Binding var document: MarkdownText
    let fileURL: URL?

    @State private var controller = EditorController()
    @State private var preview: PreviewModel?
    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.showPreviewKey) private var showPreview = true

    var body: some View {
        HSplitView {
            MarkdownEditor(text: $document.text, fontSize: fontSize, controller: controller) { index in
                preview?.scroll(toHeadingIndex: index)
            }
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

            if showPreview, let preview {
                PreviewHost(webView: preview.webView)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .onAppear { rebuildPreview() }
        .onChange(of: fileURL) { rebuildPreview() }
        .onChange(of: document.text) { preview?.textDidChange(document.text) }
        .onChange(of: fontSize) { preview?.setZoom(fontSize / EditorSettings.defaultFontSize) }
        .focusedSceneValue(\.editorController, controller)
    }

    /// Recreated when the file is first saved or moved, so relative links resolve against the new location.
    private func rebuildPreview() {
        let model = PreviewModel(fileURL: fileURL, text: document.text)
        model.setZoom(fontSize / EditorSettings.defaultFontSize)
        preview = model
    }
}

private struct PreviewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
