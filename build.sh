#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/public"

rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"

# Only look at the first frontmatter block, so slide-level `title:` doesn't win.
deck_title() {
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside && /^title:/ {
      sub(/^title:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "$1"
}

html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

items=""
for f in decks/*.md; do
  slug="$(basename "$f" .md)"
  echo "==> building $slug"
  npx slidev build "$f" --base "${BASE}${slug}/" --out "$OUT/$slug"

  title="$(deck_title "$f")"
  title="${title:-$slug}"
  items+="    <li><a href=\"${slug}/\">$(html_escape "$title")</a> <span>${slug}/</span></li>"$'\n'
done

cat > "$OUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>talks</title>
  <style>
    html { background: #0d1117; }
    body {
      margin: 0 auto;
      padding: 2rem 1.25rem;
      max-width: 48rem;
      color: #c9d1d9;
      font: 16px/1.6 ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
    }
    h1 { font-size: 1.1rem; font-weight: normal; color: #7ee787; margin: 0 0 1.5rem; }
    h1::after { content: "_"; margin-left: .15em; color: #7ee787; }
    ul { list-style: none; padding: 0; margin: 0; }
    li { padding: .4rem 0; border-bottom: 1px dashed #30363d; word-break: break-word; }
    li::before { content: "drwxr-xr-x  "; color: #484f58; }
    a { color: #79c0ff; text-decoration: none; }
    a:hover, a:focus { text-decoration: underline; }
    span { color: #8b949e; }
    @media (max-width: 480px) {
      body { font-size: 15px; padding: 1.25rem 1rem; }
      li::before { content: "> "; }
      span { display: block; }
    }
  </style>
</head>
<body>
  <h1>\$ ls /talks</h1>
  <ul>
${items}  </ul>
</body>
</html>
HTML

echo "==> done: $OUT"
