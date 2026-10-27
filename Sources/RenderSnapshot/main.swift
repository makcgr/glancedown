// Dev tool: renders a Markdown file through RenderCore and saves a PNG of the page.
// Usage: render-snapshot <file.md> <out.png> [--dark] [--width 980] [--zoom 1.0]
import AppKit
import RenderCore
import WebKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: render-snapshot <file.md> <out.png> [--dark] [--width N] [--zoom Z]\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let isDark = arguments.contains("--dark")
func option(_ name: String) -> Double? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return Double(arguments[index + 1])
}
let width = option("--width") ?? 980
let zoom = option("--zoom") ?? 1.0

final class Snapshotter: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give Mermaid and KaTeX time to load and render.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                let height = (result as? Double) ?? 2000
                webView.frame.size.height = CGFloat(height * zoom)
                let configuration = WKSnapshotConfiguration()
                configuration.rect = webView.bounds
                webView.takeSnapshot(with: configuration) { image, error in
                    guard let image, let tiff = image.tiffRepresentation,
                          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                    else {
                        FileHandle.standardError.write(Data("snapshot failed: \(String(describing: error))\n".utf8))
                        exit(1)
                    }
                    try? png.write(to: output)
                    print("wrote \(output.path) (\(Int(height)) px tall)")
                    exit(0)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        FileHandle.standardError.write(Data("load failed: \(error)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let page = DocumentPage(fileURL: input)
let webView = MainActor.assumeIsolated { PageWebView.make(page: page) }
webView.frame = NSRect(x: 0, y: 0, width: width, height: 800)
webView.pageZoom = zoom
webView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = webView
let delegate = Snapshotter()
webView.navigationDelegate = delegate
webView.load(URLRequest(url: page.pageURL))
DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    FileHandle.standardError.write(Data("timed out\n".utf8))
    exit(1)
}
app.run()
