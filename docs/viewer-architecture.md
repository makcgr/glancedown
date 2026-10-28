# Glancedown viewer: architecture

Glancedown is a small SwiftUI app that only displays Markdown. It shares its rendering engine, the
`RenderCore` library, with the editor and the Quick Look extension.

## Components

```
 ┌────────────────────────────── Glancedown.app ──────────────────────────────────┐
 │                                                                                │
 │  GlancedownApp ── DocumentGroup(viewing: MarkdownFile)                         │
 │      │              read-only documents: no save, no "edited" state            │
 │      │                                                                         │
 │      ├─ ViewerCommands ── zoom ⌘+ ⌘− ⌘0, find ⌘F ⌘G, reload ⌘R,                │
 │      │        │           print ⌘P, Open in Editor ⌘E, Show in Finder ⇧⌘R      │
 │      │        │  reaches the focused window through a FocusedValue             │
 │      ▼        ▼                                                                │
 │  DocumentView ── NavigationSplitView                                           │
 │   ┌──────────────────────┐   ┌─────────────────────────────────────────────┐   │
 │   │ OutlineSidebar       │   │ WebViewHost + FindBar overlay               │   │
 │   │  headings list,      │   │  zoom level from @AppStorage("zoom")        │   │
 │   │  current one marked  │   │                                             │   │
 │   └──────────┬───────────┘   └──────────────────────┬──────────────────────┘   │
 │              │ click → scroll                       │                          │
 │              ▼                                      ▼                          │
 │  DocumentModel (one per window, @Observable)                                   │
 │   ├─ PageWebView (WKWebView) ── pageZoom, find, print                          │
 │   ├─ FileWatcher ── file changed on disk → reload() → update(html) in place    │
 │   │                 handles atomic saves, waits 100 ms                         │
 │   ├─ NavigationHandler ── link clicked → DocumentPage.linkAction:              │
 │   │                         .md → new Glancedown window                        │
 │   │                         other local file → its default app                 │
 │   │                         http(s), mailto → browser / mail app               │
 │   ├─ messages from the page: outline, active heading, reload request           │
 │   └─ EditorLauncher ── ⌘E: Glancedown Editor, else VS Code, Cursor, … TextEdit │
 └──────────────────────────────────────┬─────────────────────────────────────────┘
                                        │ uses
 ┌──────────────────────────────────────▼─────────────────────────────────────────┐
 │  RenderCore (shared with the editor and Quick Look)                            │
 │                                                                                │
 │  DocumentPage ── reads the file from disk                                      │
 │     │            root = nearest folder with .git, else the file's folder       │
 │     │                                                                          │
 │     ├─► MarkdownRenderer ── cmark-gfm (GFM + footnotes), raw HTML dropped,     │
 │     │                       $$…$$ turned into math fences                      │
 │     │                                                                          │
 │     └─► GlancedownSchemeHandler ── glancedown://asset/…  bundled JS/CSS        │
 │                                    glancedown://doc/…    images in the project │
 │                                    (paths and symlinks limited to the root)    │
 │                                                                                │
 │  Web/  index.html (strict CSP) + app.js                                        │
 │        highlight.js · Mermaid (loaded when used) · KaTeX (loaded when used)    │
 │        github-markdown.css, light and dark                                     │
 │        app.js builds the outline and reports the visible heading               │
 └────────────────────────────────────────────────────────────────────────────────┘

 ┌──── GlancedownQuickLook.appex (inside Glancedown.app/Contents/PlugIns) ────────┐
 │  PreviewViewController ── WKWebView + RenderCore, sandboxed, read-only.        │
 │  Root = the file's folder. Links do nothing. No live reload, no outline.       │
 └────────────────────────────────────────────────────────────────────────────────┘
```

Source files: `Sources/Glancedown/` (the app), `Sources/GlancedownQuickLook/` (Quick Look) and
`Sources/RenderCore/` (the shared engine).

## What happens when the file changes on disk

1. `FileWatcher` gets an event from the kernel. If the editor saved by replacing the file, the watcher
   starts watching the new file.
2. After 100 ms without new events, `DocumentModel.reload()` asks `DocumentPage` for new HTML.
3. `PageWebView` replaces only the page body through JavaScript. The scroll position, the zoom and the
   loaded scripts stay.
4. `app.js` highlights the new code, draws diagrams and math, and sends the new outline to the sidebar.

**Outline.** `app.js` collects the headings and sends them to Swift through a script message.
While you scroll, it reports the visible heading, and the sidebar marks it. A click in the sidebar
scrolls the page to that heading.

**Zoom.** ⌘+ / ⌘− change `WKWebView.pageZoom` in steps of 1.1×, from 0.5× to 3×. The level is saved
in `@AppStorage`, so all windows and the next launch use it.

**Security.** Raw HTML is dropped, `javascript:` and `file:` links are removed, and the page cannot
load scripts from outside the app or make network requests. Local files are served only from the
document's root.

**Memory.** One `WKWebView` per window. Mermaid and KaTeX load only when a document uses them.
There is no Electron and no bundled browser.

## Dependencies

### Bundled libraries

| Library | What it does |
|---|---|
| **swift-cmark (cmark-gfm)** | GitHub's own Markdown parser, written in C. It turns Markdown text into HTML. It supports GitHub tables, task lists and footnotes. |
| **highlight.js** | Colours the code inside code blocks. It supports 35+ languages and works offline. |
| **Mermaid** | Draws diagrams from text, such as flowcharts and sequence diagrams. It is large, so it loads only when needed. |
| **KaTeX** | Shows math formulas written between `$…$` or `$$…$$`. It is fast and loads only when needed. |
| **github-markdown-css** | A style sheet that makes the page look like GitHub. It has light and dark versions. |

Pinned versions are in `scripts/fetch-vendor.sh`. Licenses are in `THIRD_PARTY_NOTICES.md`.

### macOS system frameworks (nothing extra to install)

| Framework | What it does |
|---|---|
| **WebKit (WKWebView)** | The engine of Safari, used here to show the page. The page runs in a separate process. |
| **SwiftUI DocumentGroup (NSDocument)** | Apple's standard support for document apps. Here it opens files read-only and manages windows. |
| **Dispatch (DispatchSource)** | Gets file change events from the macOS kernel. It powers live reload without polling. |
| **Quick Look (QuickLookUI)** | The system preview on Space in Finder. Glancedown adds a sandboxed extension for Markdown. |
