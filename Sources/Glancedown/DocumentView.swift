import RenderCore
import SwiftUI
import WebKit

struct DocumentView: View {
    let fileURL: URL?
    /// Created once on appear: building it in `body` would start a new web view on every re-render.
    @State private var model: DocumentModel?

    var body: some View {
        Group {
            if let model {
                LoadedDocumentView(model: model)
            } else if fileURL == nil {
                ContentUnavailableView("No file", systemImage: "doc.text")
            } else {
                Color.clear
            }
        }
        .onAppear {
            if model == nil, let fileURL {
                model = DocumentModel(fileURL: fileURL)
            }
        }
    }
}

private struct LoadedDocumentView: View {
    let model: DocumentModel
    @AppStorage(ZoomSetting.key) private var zoom = ZoomSetting.default

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 360)
        } detail: {
            WebViewHost(webView: model.webView)
                .overlay(alignment: .topTrailing) {
                    if model.isFindBarVisible {
                        FindBar(model: model)
                            .padding(10)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { model.setZoom(zoom) }
        .onChange(of: zoom) { model.setZoom(zoom) }
        .focusedSceneValue(\.documentModel, model)
    }
}

private struct OutlineSidebar: View {
    let model: DocumentModel

    var body: some View {
        let minimumLevel = model.outline.map(\.level).min() ?? 1
        List(model.outline, selection: Binding(
            get: { model.activeHeadingID },
            set: { id in
                if let item = model.outline.first(where: { $0.id == id }) {
                    model.scroll(to: item)
                }
            }
        )) { item in
            Text(item.title)
                .lineLimit(1)
                .padding(.leading, CGFloat(item.level - minimumLevel) * 12)
                .tag(item.id)
        }
        .overlay {
            if model.outline.isEmpty {
                Text("No headings")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FindBar: View {
    @Bindable var model: DocumentModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("Find", text: $model.findText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($isFieldFocused)
                .onSubmit { model.find(backwards: NSEvent.modifierFlags.contains(.shift)) }
                .onChange(of: model.findText) { model.find() }
                .onExitCommand { model.hideFindBar() }
                .foregroundStyle(model.findHasNoMatch ? .red : .primary)
            Button { model.find(backwards: true) } label: { Image(systemName: "chevron.up") }
            Button { model.find() } label: { Image(systemName: "chevron.down") }
            Button { model.hideFindBar() } label: { Image(systemName: "xmark") }
        }
        .buttonStyle(.borderless)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .onAppear { isFieldFocused = true }
    }
}

private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
