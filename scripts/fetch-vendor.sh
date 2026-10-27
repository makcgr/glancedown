#!/usr/bin/env bash
# Downloads the pinned third-party web assets into Sources/RenderCore/Web/vendor.
set -euo pipefail

HLJS=11.12.0
MERMAID=12.2.0
KATEX=0.19.0
GHCSS=5.9.0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Sources/RenderCore/Web/vendor"
CDN=https://cdn.jsdelivr.net/npm
rm -rf "$OUT" && mkdir -p "$OUT/katex/fonts"

fetch() { curl -fsSL "$CDN/$1" -o "$OUT/$2"; }

fetch "@highlightjs/cdn-assets@$HLJS/highlight.min.js" highlight.min.js
fetch "@highlightjs/cdn-assets@$HLJS/styles/github.min.css" hljs-light.css
fetch "@highlightjs/cdn-assets@$HLJS/styles/github-dark.min.css" hljs-dark.css
fetch "github-markdown-css@$GHCSS/github-markdown.css" github-markdown.css
fetch "mermaid@$MERMAID/dist/mermaid.min.js" mermaid.min.js
fetch "katex@$KATEX/dist/katex.min.js" katex/katex.min.js
fetch "katex@$KATEX/dist/katex.min.css" katex/katex.min.css

for font in $(grep -oE 'fonts/[A-Za-z0-9_-]+\.woff2' "$OUT/katex/katex.min.css" | sort -u); do
  fetch "katex@$KATEX/dist/$font" "katex/$font"
done

cat > "$OUT/VERSIONS" <<V
highlight.js $HLJS
mermaid $MERMAID
katex $KATEX
github-markdown-css $GHCSS
V
echo "vendor assets in $OUT"
