#!/usr/bin/env bash
# Render an explainer page in both themes and cut it into slices you can read.
#
#   render.sh <page.html> [out-dir] [slice-height]
#
# Writes <out-dir>/dark-0.png, dark-1.png, ... and light-0.png, ... and prints
# their paths. out-dir defaults to <page-dir>/render, slice-height to 1500.
# Works on Linux and macOS: needs Chrome or Chromium, and for slicing either
# uv, a python3 with Pillow, or (macOS) sips.
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }
[[ ${1:-} == -h || ${1:-} == --help ]] && { usage; exit 0; }
[[ $# -ge 1 && -f $1 ]] || { usage >&2; echo "render.sh: page not found: ${1:-<none>}" >&2; exit 2; }

page=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
out=${2:-$(dirname "$page")/render}
slice=${3:-1500}
mkdir -p "$out"
out=$(cd "$out" && pwd) # Chrome needs an absolute file:// URL

chrome=""
for c in google-chrome google-chrome-stable chromium chromium-browser \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
  if command -v "$c" >/dev/null 2>&1; then chrome=$(command -v "$c"); break; fi
  [[ -x $c ]] && { chrome=$c; break; }
done
[[ -n $chrome ]] || { echo "render.sh: no Chrome or Chromium found" >&2; exit 2; }

# Pick the slicer before rendering, so a missing one fails fast.
if command -v uv >/dev/null 2>&1; then
  py=(uv run -q --with pillow python -I)
elif python3 -c 'import PIL' >/dev/null 2>&1; then
  py=(python3 -I)
elif command -v sips >/dev/null 2>&1; then
  py=()
else
  echo "render.sh: cannot slice: install uv, Pillow for python3, or use macOS (sips)" >&2
  exit 2
fi

for theme in dark light; do
  # A copy with the theme fixed: --force-dark-mode follows the OS, not the tokens.
  { echo "<html data-theme=\"$theme\">"; cat "$page"; } >"$out/$theme.html"
  # Tall enough for a long page; the slicer trims the empty bottom.
  # virtual-time-budget gives Google Fonts time to load before the capture.
  timeout 120 "$chrome" --headless=new --hide-scrollbars --disable-gpu \
    --window-size=1200,12000 --virtual-time-budget=8000 \
    --screenshot="$out/$theme.png" "file://$out/$theme.html" >/dev/null 2>&1
  [[ -s $out/$theme.png ]] || { echo "render.sh: Chrome made no screenshot for $theme" >&2; exit 1; }
  rm -f "$out/$theme"-[0-9]*.png
done

if [[ ${#py[@]} -gt 0 ]]; then
  "${py[@]}" - "$out" "$slice" <<'EOF'
import sys
from PIL import Image, ImageChops
out, slice_h = sys.argv[1], int(sys.argv[2])
for theme in ("dark", "light"):
    im = Image.open(f"{out}/{theme}.png").convert("RGB")
    # Trim the empty bottom: the page background is the colour of the last row.
    bg = Image.new("RGB", im.size, im.getpixel((5, im.height - 5)))
    box = ImageChops.difference(im, bg).getbbox()
    h = min(im.height, (box[3] if box else im.height) + 40)
    for i, top in enumerate(range(0, h, slice_h)):
        p = f"{out}/{theme}-{i}.png"
        im.crop((0, top, im.width, min(h, top + slice_h))).save(p)
        print(p)
EOF
else
  # sips cannot trim; it cuts fixed slices from the full height.
  for theme in dark light; do
    full=$(sips -g pixelHeight "$out/$theme.png" | awk '/pixelHeight/{print $2}')
    i=0
    for ((top = 0; top < full; top += slice)); do
      h=$((full - top < slice ? full - top : slice))
      sips -c "$h" 1200 --cropOffset "$top" 0 "$out/$theme.png" --out "$out/$theme-$i.png" >/dev/null
      echo "$out/$theme-$i.png"
      i=$((i + 1))
    done
  done
fi
