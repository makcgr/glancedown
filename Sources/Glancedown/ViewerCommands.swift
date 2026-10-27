import SwiftUI

enum ZoomSetting {
    static let key = "zoom"
    static let `default` = 1.0
    static let range = 0.5...3.0
    static let step = 1.1
}

private struct DocumentModelKey: FocusedValueKey {
    typealias Value = DocumentModel
}

extension FocusedValues {
    var documentModel: DocumentModel? {
        get { self[DocumentModelKey.self] }
        set { self[DocumentModelKey.self] = newValue }
    }
}

struct ViewerCommands: Commands {
    @FocusedValue(\.documentModel) private var model
    @AppStorage(ZoomSetting.key) private var zoom = ZoomSetting.default

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print…") { model?.print() }
                .keyboardShortcut("p")
                .disabled(model == nil)
        }

        CommandGroup(after: .saveItem) {
            Button("Open in Editor") { model?.openInEditor() }
                .keyboardShortcut("e")
                .disabled(model == nil)
            Button("Show in Finder") { model?.revealInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model == nil)
        }

        CommandGroup(after: .textEditing) {
            Button("Find…") { model?.showFindBar() }
                .keyboardShortcut("f")
            Button("Find Next") { model?.find() }
                .keyboardShortcut("g")
            Button("Find Previous") { model?.find(backwards: true) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        CommandGroup(before: .toolbar) {
            Button("Actual Size") { zoom = ZoomSetting.default }
                .keyboardShortcut("0")
            Button("Zoom In") { setZoom(zoom * ZoomSetting.step) }
                .keyboardShortcut("+")
            Button("Zoom Out") { setZoom(zoom / ZoomSetting.step) }
                .keyboardShortcut("-")
            Divider()
            Button("Reload") { model?.reload() }
                .keyboardShortcut("r")
                .disabled(model == nil)
            Divider()
        }
    }

    private func setZoom(_ value: Double) {
        zoom = min(max(value, ZoomSetting.range.lowerBound), ZoomSetting.range.upperBound)
    }
}
