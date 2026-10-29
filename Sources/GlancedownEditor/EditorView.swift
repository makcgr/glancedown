import SwiftUI
import WebKit

enum EditorSettings {
    static let fontSizeKey = "editorFontSize"
    static let defaultFontSize = 13.0
    static let fontSizeRange = 9.0...32.0
    static let showPreviewKey = "showPreview"
}

struct EditorView: View {
    @Bindable var state: EditorState
    let controller: EditorController

    @State private var preview: PreviewModel?
    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.showPreviewKey) private var showPreview = true

    var body: some View {
        HSplitView {
            MarkdownEditor(text: $state.text, fontSize: fontSize, controller: controller) { index in
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
        .onChange(of: state.fileURL) { rebuildPreview() }
        .onChange(of: state.text) { preview?.textDidChange(state.text) }
        .onChange(of: fontSize) { preview?.setZoom(fontSize / EditorSettings.defaultFontSize) }
    }

    /// Recreated when the file is first saved or moved, so relative links resolve against the new location.
    private func rebuildPreview() {
        let model = PreviewModel(fileURL: state.fileURL, text: state.text)
        model.setZoom(fontSize / EditorSettings.defaultFontSize)
        preview = model
    }
}

private struct PreviewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
