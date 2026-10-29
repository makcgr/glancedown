# Glancedown Editor: architecture

Glancedown Editor is a small AppKit app with a SwiftUI window. It shares its rendering engine, the `RenderCore` library,
with the viewer and the Quick Look extension.

## Components

```
 ┌──────────────────────────── Glancedown Editor.app ─────────────────────────────┐
 │                                                                                │
 │  main.swift ── NSApplication + MainMenu (built in code) + AppDelegate          │
 │      │                                                                         │
 │  MarkdownDocument ── NSDocument, autosavesInPlace = false                      │
 │      │  classic Save: ⌘S, Save As, Revert; "Save changes?" on close and quit   │
 │      │  Format menu (⌘B ⌘I ⌘K …) reaches it through the responder chain        │
 │      │  EditorWindowController: hosts SwiftUI, gives the text view its undo    │
 │      ▼                                                                         │
 │  EditorView ── HSplitView                                                      │
 │   ┌───────────────────────────────┐        ┌───────────────────────────────┐   │
 │   │ MarkdownEditor (left)         │        │ Preview (right)               │   │
 │   │  NSViewRepresentable          │        │                               │   │
 │   │  └─ NSTextView (TextKit 2)    │  text  │ PreviewModel                  │   │
 │   │       + system find bar       │ ─────► │  waits 150 ms after typing    │   │
 │   │                               │        │  unsaved doc → temp Untitled  │   │
 │   │  EditorController             │        │        │                      │   │
 │   │   wrapSelection / insertLink  │        │        ▼                      │   │
 │   │   (undo works: insertText)    │        │ PageWebView (WKWebView)       │   │
 │   │                               │ scroll │   update(html) in place,      │   │
 │   │  SyntaxHighlighter            │ ─────► │   scroll position kept        │   │
 │   │   colours tokens; waits 0.3 s │ heading│   scrollToHeading(index:)     │   │
 │   │   after typing if > 100 KB    │ index  │                               │   │
 │   └──────────────┬────────────────┘        └──────────────┬────────────────┘   │
 └──────────────────┼────────────────────────────────────────┼────────────────────┘
                    │ uses                                   │ uses
 ┌──────────────────▼────────────────────────────────────────▼────────────────────┐
 │  RenderCore (shared with the viewer and Quick Look)                            │
 │                                                                                │
 │  MarkdownSyntax ── line + regex tokenizer:                                     │
 │     headings, code, emphasis, links, lists, quotes                             │
 │     headingIndex(atOffset:) → which section the cursor is in                   │
 │                                                                                │
 │  DocumentPage ── contentProvider = live editor text (not the file on disk)     │
 │     │                                                                          │
 │     ├─► MarkdownRenderer ── cmark-gfm (GFM + footnotes), raw HTML dropped,     │
 │     │                       $$…$$ turned into math fences                      │
 │     │                                                                          │
 │     └─► GlancedownSchemeHandler ── glancedown://asset/…  bundled JS/CSS        │
 │                                    glancedown://doc/…    images next to the doc│
 │                                    (paths limited to the doc's project)        │
 │                                                                                │
 │  Web/  index.html (strict CSP) + app.js                                        │
 │        highlight.js · Mermaid (loaded when used) · KaTeX (loaded when used)    │
 │        github-markdown.css, light and dark                                     │
 └────────────────────────────────────────────────────────────────────────────────┘
```

Source files: `Sources/GlancedownEditor/` (the app) and `Sources/RenderCore/` (the shared engine).

## What happens when you type

1. `NSTextView` registers the change with the document's undo manager, so the document is marked as
   changed. The editor copies the new text to the document at once, also after undo, redo and Replace All.
2. `MarkdownSyntax` splits the text into tokens, and `SyntaxHighlighter` colours them. This runs at once.
   For text over 100 KB it waits until 0.3 s after the last key press.
3. 150 ms after the last key press, `PreviewModel` asks `DocumentPage` for new HTML. `DocumentPage`
   reads the editor text, not the file on disk.
4. `PageWebView` replaces only the page body through JavaScript, so the preview keeps its scroll position.

**Scroll sync.** When you scroll the text, the editor finds the heading at the top of the view
(`headingIndex`). The preview then scrolls to the heading with the same number.

**Saving.** The editor saves only when you ask: ⌘S, or **Save As** with ⇧⌘S. Closing a window or
quitting the app with unsaved changes asks "Save changes?". **File → Revert to Saved** drops the
unsaved changes. Autosave is off on purpose (`autosavesInPlace = false`).

**Memory.** One native text view and one `WKWebView`. Mermaid and KaTeX load only when a document uses
them. There is no Electron and no bundled browser.

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
| **WebKit (WKWebView)** | The engine of Safari, used here to show the preview. The page runs in a separate process. |
| **TextKit 2 (NSTextView)** | The native macOS text editor component. It gives typing, undo, find and replace, and spell check. |
| **AppKit NSDocument** | Apple's standard support for document apps. It handles open, save, the "Save changes?" question and recent files. |
| **SwiftUI** | Draws the editor window: the split view, the text pane and the preview pane. |
