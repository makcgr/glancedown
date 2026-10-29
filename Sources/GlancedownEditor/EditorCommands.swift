import AppKit

/// App-wide view settings, at the end of the responder chain so they work with or without a window.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var defaults: UserDefaults { .standard }

    private var fontSize: Double {
        get { defaults.object(forKey: EditorSettings.fontSizeKey) as? Double ?? EditorSettings.defaultFontSize }
        set {
            let range = EditorSettings.fontSizeRange
            defaults.set(min(max(newValue, range.lowerBound), range.upperBound), forKey: EditorSettings.fontSizeKey)
        }
    }

    private var showPreview: Bool {
        get { defaults.object(forKey: EditorSettings.showPreviewKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: EditorSettings.showPreviewKey) }
    }

    @objc func togglePreview(_ sender: Any?) { showPreview.toggle() }
    @objc func actualSize(_ sender: Any?) { fontSize = EditorSettings.defaultFontSize }
    @objc func biggerFont(_ sender: Any?) { fontSize += 1 }
    @objc func smallerFont(_ sender: Any?) { fontSize -= 1 }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePreview(_:)) {
            menuItem.state = showPreview ? .on : .off
        }
        return true
    }
}

/// The main menu, built in code because the app has no nib.
enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu(appMenu()))
        menu.addItem(submenu(fileMenu()))
        menu.addItem(submenu(editMenu()))
        menu.addItem(submenu(formatMenu()))
        menu.addItem(submenu(viewMenu()))
        let window = windowMenu()
        menu.addItem(submenu(window))
        NSApp.windowsMenu = window
        return menu
    }

    private static func appMenu() -> NSMenu {
        let name = ProcessInfo.processInfo.processName
        let services = NSMenu(title: "Services")
        NSApp.servicesMenu = services
        return menu(name, [
            item("About \(name)", "orderFrontStandardAboutPanel:"),
            .separator(),
            submenu(services),
            .separator(),
            item("Hide \(name)", "hide:", "h"),
            item("Hide Others", "hideOtherApplications:", "h", [.command, .option]),
            item("Show All", "unhideAllApplications:"),
            .separator(),
            item("Quit \(name)", "terminate:", "q"),
        ])
    }

    private static func fileMenu() -> NSMenu {
        let recent = menu("Open Recent", [item("Clear Menu", "clearRecentDocuments:")])
        return menu("File", [
            item("New", "newDocument:", "n"),
            item("Open…", "openDocument:", "o"),
            submenu(recent),
            .separator(),
            item("Close", "performClose:", "w"),
            item("Save…", "saveDocument:", "s"),
            item("Save As…", "saveDocumentAs:", "s", [.command, .shift]),
            item("Revert to Saved", "revertDocumentToSaved:"),
        ])
    }

    private static func editMenu() -> NSMenu {
        let find = menu("Find", [
            item("Find…", "performFindPanelAction:", "f", tag: NSTextFinder.Action.showFindInterface),
            item("Find and Replace…", "performFindPanelAction:", "f", [.command, .option], tag: .showReplaceInterface),
            item("Find Next", "performFindPanelAction:", "g", tag: .nextMatch),
            item("Find Previous", "performFindPanelAction:", "g", [.command, .shift], tag: .previousMatch),
            item("Use Selection for Find", "performFindPanelAction:", "e", tag: .setSearchString),
        ])
        let spelling = menu("Spelling and Grammar", [
            item("Show Spelling and Grammar", "showGuessPanel:", ":"),
            item("Check Document Now", "checkSpelling:", ";"),
            item("Check Spelling While Typing", "toggleContinuousSpellChecking:"),
        ])
        return menu("Edit", [
            item("Undo", "undo:", "z"),
            item("Redo", "redo:", "z", [.command, .shift]),
            .separator(),
            item("Cut", "cut:", "x"),
            item("Copy", "copy:", "c"),
            item("Paste", "paste:", "v"),
            item("Paste and Match Style", "pasteAsPlainText:", "v", [.command, .option, .shift]),
            item("Delete", "delete:"),
            item("Select All", "selectAll:", "a"),
            .separator(),
            submenu(find),
            submenu(spelling),
        ])
    }

    private static func formatMenu() -> NSMenu {
        menu("Format", [
            item("Bold", "formatBold:", "b"),
            item("Italic", "formatItalic:", "i"),
            item("Strikethrough", "formatStrikethrough:", "x", [.command, .shift]),
            item("Inline Code", "formatInlineCode:", "c", [.command, .shift]),
            item("Link", "formatLink:", "k"),
        ])
    }

    private static func viewMenu() -> NSMenu {
        let biggerAlias = item("Bigger", "biggerFont:", "=")
        biggerAlias.isHidden = true
        biggerAlias.allowsKeyEquivalentWhenHidden = true
        return menu("View", [
            item("Show Preview", "togglePreview:", "p", [.command, .option]),
            .separator(),
            item("Actual Size", "actualSize:", "0"),
            item("Bigger", "biggerFont:", "+"),
            biggerAlias,
            item("Smaller", "smallerFont:", "-"),
        ])
    }

    private static func windowMenu() -> NSMenu {
        menu("Window", [
            item("Minimize", "performMiniaturize:", "m"),
            item("Zoom", "performZoom:"),
            .separator(),
            item("Bring All to Front", "arrangeInFront:"),
        ])
    }

    private static func item(
        _ title: String,
        _ action: String,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command,
        tag: NSTextFinder.Action? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(action), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        if let tag {
            item.tag = tag.rawValue
        }
        return item
    }

    private static func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
