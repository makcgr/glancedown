# Contributing

Thanks for helping. Small, focused pull requests are easiest to review.

## Build and test

Requirements: macOS 14+, Swift 6 (Xcode 16+ or the Command Line Tools).

```bash
./scripts/test.sh            # unit tests (works with Xcode or Command Line Tools)
./scripts/bundle.sh          # builds build/Glancedown.app
open build/Glancedown.app --args fixtures/features.md
```

Render a fixture to a PNG without opening the app:

```bash
swift build --product RenderSnapshot
.build/debug/RenderSnapshot fixtures/features.md /tmp/features.png --dark
```

## Project layout

| Path | What it holds |
|---|---|
| `Sources/RenderCore` | Markdown → HTML, the `glancedown://` scheme handler, the page template and scripts. Shared by every target. |
| `Sources/Glancedown` | The viewer app (SwiftUI). |
| `Sources/GlancedownQuickLook` | The Quick Look preview extension. |
| `Sources/RenderSnapshot` | Dev tool that renders a file to PNG; used in CI. |
| `fixtures/` | Sample documents, including `hostile.md`, which must always render inert. |

## Third-party web assets

Versions are pinned in `scripts/fetch-vendor.sh`. To update one, change the version, run the script, check the fixtures, and update `THIRD_PARTY_NOTICES.md`.

## Security

Do not report security issues in public issues. Use GitHub's private vulnerability reporting on this repository.
