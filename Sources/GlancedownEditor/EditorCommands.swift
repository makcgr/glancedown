import SwiftUI

private struct EditorControllerKey: FocusedValueKey {
    typealias Value = EditorController
}

extension FocusedValues {
    var editorController: EditorController? {
        get { self[EditorControllerKey.self] }
        set { self[EditorControllerKey.self] = newValue }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorController) private var controller
    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.showPreviewKey) private var showPreview = true

    var body: some Commands {
        CommandMenu("Format") {
            Button("Bold") { controller?.wrapSelection("**") }
                .keyboardShortcut("b")
            Button("Italic") { controller?.wrapSelection("*") }
                .keyboardShortcut("i")
            Button("Strikethrough") { controller?.wrapSelection("~~") }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            Button("Inline Code") { controller?.wrapSelection("`") }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Link") { controller?.insertLink() }
                .keyboardShortcut("k")
        }

        CommandGroup(before: .toolbar) {
            Toggle("Show Preview", isOn: $showPreview)
                .keyboardShortcut("p", modifiers: [.command, .option])
            Divider()
            Button("Actual Size") { fontSize = EditorSettings.defaultFontSize }
                .keyboardShortcut("0")
            Button("Bigger") { setFontSize(fontSize + 1) }
                .keyboardShortcut("+")
            Button("Smaller") { setFontSize(fontSize - 1) }
                .keyboardShortcut("-")
            Divider()
        }
    }

    private func setFontSize(_ value: Double) {
        fontSize = min(max(value, EditorSettings.fontSizeRange.lowerBound), EditorSettings.fontSizeRange.upperBound)
    }
}
