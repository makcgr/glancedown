# Changelog

## 0.1.0 — unreleased

First public version.

- GitHub-flavored Markdown: tables, task lists, strikethrough, autolinks, footnotes.
- Offline syntax highlighting for fenced code blocks (highlight.js, light and dark themes) with a copy button.
- Zoom in / out / actual size (⌘+ / ⌘− / ⌘0), remembered between launches; pinch to zoom.
- Live reload when the file changes on disk, keeping the scroll position.
- Outline sidebar built from the headings, with the current section highlighted.
- Mermaid diagrams and KaTeX math (`$…$`, `$$…$$`, ```math blocks), loaded only when a document uses them.
- Quick Look extension: press Space on a Markdown file in Finder.
- Find (⌘F), Open in Editor (⌘E), Print / Save as PDF (⌘P).
- Glancedown Editor: a separate lightweight editor with Markdown syntax colouring, a live preview that follows the edited section, and format shortcuts. It saves only on ⌘S and asks before closing unsaved changes.
- Safe by default: raw HTML is dropped, a strict Content Security Policy blocks scripts from documents, and local files are served only from the document's folder or repository.
