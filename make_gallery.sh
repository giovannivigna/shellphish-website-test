#!/bin/bash
set -e

PHOTO_DIR="$1"
THUMB_DIR="$PHOTO_DIR/thumbs"
HTML_FILE="$PHOTO_DIR/index.html"

if [[ -z "$PHOTO_DIR" || ! -d "$PHOTO_DIR" ]]; then
  echo "Usage: $0 <photo-directory>"
  exit 1
fi

mkdir -p "$THUMB_DIR"

echo "Generating thumbnails in $THUMB_DIR..."
find "$PHOTO_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | while read -r img; do
  fname=$(basename "$img")
  convert "$img" -resize x200 -gravity center -background black -extent 300x200 "$THUMB_DIR/$fname"
done

echo "Creating HTML gallery at $HTML_FILE..."
cat > "$HTML_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Photo Gallery</title>
  <style>
    body { background:#111; color:#eee; font-family:sans-serif; text-align:center; }
    img { margin:5px; border:2px solid #333; }
    a:hover img { border-color:#69f; }
  </style>
</head>
<body>
<h1>Photo Gallery</h1>
<div>
EOF

find "$THUMB_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort | while read -r thumb; do
  full_img="$(basename "$thumb")"
  rel_thumb="thumbs/$(basename "$thumb")"
  echo "<a href=\"$full_img\" target=\"_blank\"><img src=\"$rel_thumb\" height=\"200\"></a>" >> "$HTML_FILE"
done

echo "</div></body></html>" >> "$HTML_FILE"

echo "✅ Done. Open $HTML_FILE in your browser."