#!/bin/bash
set -e

SITE_DIR="shellphish-site"
PRIVATE_DIR="private-$(openssl rand -hex 6)"

mkdir -p "$SITE_DIR/assets/css" "$SITE_DIR/assets/js" "$SITE_DIR/data" "$SITE_DIR/$PRIVATE_DIR"

# CSS
cat > "$SITE_DIR/assets/css/style.css" <<EOF
body { font-family: sans-serif; margin:0; background:#111; color:#eee; padding:0 1em; }
a { color:#69f; text-decoration:none; }
header, footer { background:#222; padding:1em; text-align:center; }
nav a { margin:0 1em; }
main { max-width:900px; margin:auto; padding:1em; }
img { max-width:100%; height:auto; }
@media (min-width:600px){ nav{ text-align:center; } }
EOF

# Shared HTML fragments
HEADER='<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Shellphish</title><link rel="stylesheet" href="assets/css/style.css"></head><body><header><h1>Shellphish</h1><nav><a href="index.html">Home</a><a href="members.html">Members</a><a href="defcon.html">DEF CON</a><a href="cgc.html">CGC</a><a href="aixcc.html">AIxCC</a></nav></header><main>'
FOOTER='</main><footer><p>© Shellphish 2005–2025</p></footer></body></html>'

# Basic pages
echo "$HEADER<h2>Welcome to Shellphish</h2><p>Founded in 2005.</p>$FOOTER" > "$SITE_DIR/index.html"
echo "$HEADER<h2>Shellphish at DEF CON</h2><p>Participation history…</p>$FOOTER" > "$SITE_DIR/defcon.html"
echo "$HEADER<h2>Shellphish and CGC</h2><p>Cyber Grand Challenge insights…</p>$FOOTER" > "$SITE_DIR/cgc.html"
echo "$HEADER<h2>Shellphish and AIxCC</h2><p>AI Cyber Challenge highlights…</p>$FOOTER" > "$SITE_DIR/aixcc.html"

# Member data and renderer
cat > "$SITE_DIR/data/members.json" <<EOF
[
  { "handle": "f00b4r", "year": 2006, "first": "Alice", "last": "Smith" },
  { "handle": "hackzor", "year": 2008 },
  { "handle": "shellbot", "year": 2010, "first": "Bob", "last": "Jones" }
]
EOF

cat > "$SITE_DIR/assets/js/main.js" <<'EOF'
fetch('data/members.json')
  .then(r=>r.json())
  .then(m=>{
    let out='';
    m.forEach(u=>{
      const name = u.first ? ` (${u.first} ${u.last})` : '';
      out += `<li><strong>${u.handle}</strong> — Joined ${u.year}${name}</li>`;
    });
    document.getElementById('member-list').innerHTML = out;
  });
EOF

cat > "$SITE_DIR/members.html" <<EOF
$HEADER
<h2>Shellphish Members</h2>
<ul id="member-list">Loading…</ul>
<script src="assets/js/main.js"></script>
$FOOTER
EOF

# Hidden members-only section
cat > "$SITE_DIR/$PRIVATE_DIR/events.html" <<EOF
$HEADER
<h2>Shellphish Memorable Events</h2>
<ul>
  <li><h3>DEF CON 21 Meetup</h3><img src="https://example.com/photo1.jpg" alt="Group photo"></li>
</ul>
$FOOTER
EOF

echo "✅ Site generated in '$SITE_DIR'"
echo "🔒 Members-only content at /$PRIVATE_DIR/ — don't link to it!"