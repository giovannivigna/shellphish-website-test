#!/bin/bash

# Generates docs/members.html from docs/data/members.json
# Requires: jq

INPUT_JSON="docs/data/members.json"
OUTPUT_HTML="docs/members.html"

# HTML header
cat > "$OUTPUT_HTML" <<'EOF'
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shellphish - Members</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>

<body>
    <header>
        <h1>Shellphish</h1>
        <nav>
            <a href="index.html">Home</a>
            <a href="members.html">Members</a>
            <a href="defcon.html">DEF CON</a>
            <a href="cgc.html">CGC</a>
            <a href="aixcc.html">AIxCC</a>
            <a href="https://support.shellphish.net">Shellphish Support Syndicate</a>
        </nav>
    </header>
    <main>
        <h2>Shellphish Members</h2>
        <ul id="member-list">
EOF

# Generate member list
jq -r '
  .[] |
  if (.first and .last) then
    "<li><strong>\(.handle)</strong> — Joined \(.year) (\(.first) \(.last))</li>"
  else
    "<li><strong>\(.handle)</strong> — Joined \(.year)</li>"
  end
' "$INPUT_JSON" >> "$OUTPUT_HTML"

# HTML footer
cat >> "$OUTPUT_HTML" <<'EOF'
        </ul>
    </main>
    <footer>
        <p>© Shellphish 2005–2025</p>
    </footer>
</body>

</html>
EOF

echo "Generated $OUTPUT_HTML from $INPUT_JSON" 