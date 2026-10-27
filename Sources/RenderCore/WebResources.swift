import Foundation

/// Locates the bundled `Web` folder (template, scripts, styles, vendor libraries).
public enum WebResources {
    static let bundleName = "Glancedown_RenderCore.bundle"

    public static let directory: URL = {
        for candidate in packagedCandidates() where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        // Test and `swift run` builds keep the SwiftPM resource bundle next to the binary.
        guard let web = Bundle.module.url(forResource: "Web", withExtension: nil) else {
            fatalError("Glancedown web resources are missing from \(bundleName)")
        }
        return web
    }()

    /// The app ships the folder as Contents/Resources/Web; the Quick Look extension reads it from its host app.
    private static func packagedCandidates() -> [URL] {
        guard let resources = Bundle.main.resourceURL else { return [] }
        let hostAppResources = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
        return [
            resources.appendingPathComponent("Web"),
            hostAppResources.appendingPathComponent("Web"),
        ]
    }

    public static func url(for path: String) -> URL? {
        let root = directory.standardizedFileURL
        let candidate = root.appendingPathComponent(path).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else { return nil }
        return candidate
    }
}
