#!/usr/bin/env bash
#
# Regenerate the served images in static/ from the originals in source-images/.
#
# Uses only sips (ships with macOS) — no ImageMagick, no cwebp, no build step.
# The outputs are committed to the repo; this script exists so the process is
# repeatable when a source image is replaced, not so it runs at deploy time.
#
# Usage:  ./tools/optimize-images.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="source-images"
OUT="static"

if [ ! -d "$SRC" ]; then
    echo "error: $SRC/ not found — originals must live there." >&2
    exit 1
fi

# The project thumbnails render at ~240px CSS, so 720px covers 3x displays.
# Reddit.png is a graphviz dump whose labels are unreadable at any thumbnail
# size, so it gets less — it is the single largest asset otherwise.
THUMB_WIDTH=720
REDDIT_WIDTH=480

# Both derivatives are cropped ABOVE y~2000 in the 4608x2592 original. A
# centred crop includes the "PORTOLA" wordmark on the sweatshirt, which
# contradicts the rest of the site (Caltech now, Portola as alumniOf only) and
# would be the first thing a reader sees on a shared link. Hence --cropOffset
# rather than plain -c.
FACE_TOP=60          # a little headroom above the hair
SAFE_BOTTOM=1960     # last row before the wordmark starts

echo "==> Social card (1200x630)"
# 1.9048:1 is the OpenGraph ratio; crop to it before scaling or sips letterboxes.
og_h=$(( SAFE_BOTTOM - FACE_TOP ))          # 1900
og_w=$(( og_h * 1200 / 630 ))               # 3619
og_x=$(( (4608 - og_w) / 2 ))
sips -c "$og_h" "$og_w" --cropOffset "$FACE_TOP" "$og_x" \
     "$SRC/DSC08945.png" --out "$OUT/og-card.jpg" \
     -s format jpeg -s formatOptions 80 >/dev/null
sips -z 630 1200 "$OUT/og-card.jpg" >/dev/null

echo "==> Portrait (600x600 square)"
sq=$(( SAFE_BOTTOM - FACE_TOP ))            # 1900
sq_x=$(( 2304 - sq / 2 ))                   # centred on the face, not the frame
sips -c "$sq" "$sq" --cropOffset "$FACE_TOP" "$sq_x" \
     "$SRC/DSC08945.png" --out "$OUT/portrait.jpg" \
     -s format jpeg -s formatOptions 82 >/dev/null
sips -z 600 600 "$OUT/portrait.jpg" >/dev/null

echo "==> Project thumbnails"
# These stay PNG: they are plots and renders with flat colour and fine lines,
# which JPEG's chroma subsampling smears.
#
# sips always writes 24-bit PNG, so on an already-palettised source it can
# produce a *larger* file even at a smaller pixel size. Keep whichever wins.
for name in setup2 combined_mcmc_prometheus_models-1 C_UV_08 Reddit; do
    if [ ! -f "$SRC/$name.png" ]; then
        echo "    skip $name.png (not in $SRC/)"
        continue
    fi

    width=$THUMB_WIDTH
    [ "$name" = "Reddit" ] && width=$REDDIT_WIDTH

    sips -Z "$width" "$SRC/$name.png" --out "$OUT/$name.png" >/dev/null

    src_bytes=$(stat -f%z "$SRC/$name.png")
    out_bytes=$(stat -f%z "$OUT/$name.png")
    note=""
    if [ "$out_bytes" -ge "$src_bytes" ]; then
        cp "$SRC/$name.png" "$OUT/$name.png"
        note="(kept original — resize encoded larger)"
    fi

    printf '    %-40s %6s  %s\n' \
        "$name.png" "$(du -h "$OUT/$name.png" | cut -f1)" "$note"
done

echo
echo "==> Result"
du -sh "$OUT"
