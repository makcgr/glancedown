import AppKit

MainActor.assumeIsolated {
    _ = NSDocumentController.shared
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.mainMenu = MainMenu.make()
    app.run()
}
