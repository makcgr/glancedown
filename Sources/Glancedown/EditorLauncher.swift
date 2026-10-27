import AppKit

/// Opens a file in a text editor: Glancedown Editor when installed, otherwise a common code editor.
enum EditorLauncher {
    /// Set with `defaults write io.github.makcgr.glancedown editorBundleID <id>` to force an editor.
    static let preferenceKey = "editorBundleID"

    private static let knownEditors = [
        "io.github.makcgr.glancedown.editor",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "dev.zed.Zed",
        "com.sublimetext.4",
        "com.barebones.bbedit",
        "com.panic.Nova",
        "com.apple.TextEdit",
    ]

    static func open(_ file: URL) {
        guard let editor = editorURL(for: file) else {
            NSWorkspace.shared.open(file)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func editorURL(for file: URL) -> URL? {
        let workspace = NSWorkspace.shared
        var preferred = knownEditors
        if let custom = UserDefaults.standard.string(forKey: preferenceKey) {
            preferred.insert(custom, at: 0)
        }
        for bundleID in preferred {
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }
        let ownBundle = Bundle.main.bundleURL.standardizedFileURL
        return workspace.urlsForApplications(toOpen: file).first { $0.standardizedFileURL != ownBundle }
    }
}
