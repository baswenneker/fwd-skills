#!/usr/bin/env bash
# Turn an image into a data URI that fits an explainer page.
#
#   embed.sh <image> [max-width]
#
# Scales the image down to max-width (default 2160: sharp at 1080px on a
# retina screen), converts it to WebP and prints `data:image/webp;base64,...`
# on stdout. Put that in <img src="...">. The size goes to stderr: keep the
# whole page under 16 MB. Needs uv or a python3 with Pillow.
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }
[[ ${1:-} == -h || ${1:-} == --help ]] && { usage; exit 0; }
[[ $# -ge 1 && -f $1 ]] || { usage >&2; echo "embed.sh: image not found: ${1:-<none>}" >&2; exit 2; }

if command -v uv >/dev/null 2>&1; then
  py=(uv run -q --with pillow python -I)
elif python3 -c 'import PIL' >/dev/null 2>&1; then
  py=(python3 -I)
else
  echo "embed.sh: install uv, or Pillow for python3" >&2
  exit 2
fi

"${py[@]}" - "$1" "${2:-2160}" <<'EOF'
import base64, io, sys
from PIL import Image
path, max_w = sys.argv[1], int(sys.argv[2])
im = Image.open(path)
im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
if im.width > max_w:
    im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
buf = io.BytesIO()
im.save(buf, "WEBP", quality=82, method=6)
data = base64.b64encode(buf.getvalue()).decode()
print(f"embed.sh: {im.width}x{im.height}, {len(data) // 1024} KB as data URI", file=sys.stderr)
print(f"data:image/webp;base64,{data}")
EOF
