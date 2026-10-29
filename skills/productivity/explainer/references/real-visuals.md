# Real visuals — show the thing itself

A drawn diagram shows how something works. A real visual shows what it *is*: the
screen the user sees, the picture the code produced, the place on the map, the
lines the terminal printed. When the subject has such a thing, the reader believes
and grasps it faster than any box-and-arrow drawing of it. So before you draw a
section, ask: is there something real to show here? If so, show that, and draw only
the mechanism behind it.

## Which one

| The subject has… | Show | Not when |
|---|---|---|
| A screen: an app, a dashboard, a CLI with a TUI | A **screenshot**, before and after when something changed | The change is invisible on screen (a refactor, a backend fix) |
| A screen where one spot matters | An **annotated screenshot**: the shot plus numbered callouts | Everything on it matters equally — then a plain shot |
| Code that produces images, plots or reports | The **real output**: the PNG it wrote, a chart from the real CSV | The output is a wall of numbers — draw the numbers per `diagrams-numbers.md` |
| Positions on earth: ships, routes, sites, regions | A **map** rendered from the real coordinates | One location only — a sentence with the place name does it |
| A command-line tool or script | **Terminal output** as a `<pre>` block: the command and what it printed | The output runs past 25 lines and you cannot cut it to the part that matters |
| A sequence the reader should walk through, or a before/after | A **step-through or tabs**: one view at a time | The page reads fine as one static picture — interaction is a cost |

Never fake one: no mock-up drawn to look like a screenshot, no invented terminal
output, no map with made-up coordinates. A real visual is evidence; a fake one
spends that trust. If you cannot produce the real thing, draw a diagram and say it
is a diagram.

## Getting the image

**Screenshot of a page or app.** Run the app (the project's own dev command), then
capture it with headless Chrome, at the width the reader uses:

```bash
google-chrome --headless=new --hide-scrollbars --window-size=1440,900 \
  --virtual-time-budget=8000 --screenshot=shot.png "http://localhost:5173/route"
```

When the state you need takes clicks, a login or a form — a dialog open, a filter
set — use the Playwright browser tools instead (`browser_navigate`, `browser_click`,
`browser_take_screenshot`). Crop to the part that matters: a full desktop with the
change in one corner teaches nothing. For a before/after, check out the base commit
in a worktree and capture the same route at the same size.

**Real output.** Use the file the code wrote (the run's PNGs, the report's chart).
For a chart from real data, plot it with the project's own data and `uv run --with
matplotlib`, styled with the page tokens' hex values, or draw it as SVG per
`diagrams-numbers.md` — the numbers then stay selectable text.

**Map.** Render it locally to a PNG from the real coordinates; external map tiles
inside the artifact are not reliable. `staticmap` does this in a few lines:

```python
# uv run -q --with staticmap python -I map.py
from staticmap import StaticMap, Line, CircleMarker
m = StaticMap(1600, 800, url_template="https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              headers={"User-Agent": "fwd-explainer/1.0 (static map for an explainer)"})
m.add_line(Line([(4.20, 52.70), (3.90, 53.00)], "#0F6E7B", 5))   # (lon, lat)
m.add_marker(CircleMarker((3.90, 53.00), "#9C5A06", 16))
m.render(zoom=9).save("map.png")
```

Colours are the accent and warning hex values from Step 3. OpenStreetMap requires
attribution: end the caption with "Kaart © OpenStreetMap-bijdragers" (or "Map ©
OpenStreetMap contributors" on an English page).

**Terminal output.** Run the real command and copy what it printed. Keep the command
line on top, prefixed with `$`. Cut to the lines that matter and mark each cut with
a line holding only `…`. Never retype or reformat the output.

## Putting it on the page

Embed every image as a data URI — the page must stay one self-contained file:

```bash
src=$("${CLAUDE_SKILL_DIR}/scripts/embed.sh" shot.png)   # WebP, max 2160px wide
```

`embed.sh` prints the size; keep the whole page under 16 MB, which in practice
means a handful of images, not dozens. Then:

```html
<figure class="shot">
  <img src="data:image/webp;base64,..." width="2160" height="1350"
       alt="One sentence saying what the picture shows">
  <figcaption>One sentence: what the reader should see.</figcaption>
</figure>
```

```css
.shot{margin:0;display:flex;flex-direction:column;gap:8px}
.shot img{width:100%;height:auto;display:block;border:1px solid var(--rule);border-radius:12px}
.shot figcaption{font:13px/1.5 "IBM Plex Mono",monospace;color:var(--muted)}
```

The border matters: a light screenshot on a dark page has no edge without it. Same
full page width as every other card. `width`/`height` attributes hold the real pixel
size, so the page does not jump while the image decodes.

**Annotated screenshot.** Put an SVG over the image with the same `viewBox` as the
image's pixel size, so callouts land on the pixel you mean:

```html
<figure class="shot" style="position:relative">
  <div style="position:relative">
    <img src="data:..." width="2160" height="1350" alt="...">
    <svg viewBox="0 0 2160 1350" style="position:absolute;inset:0;width:100%;height:100%"
         aria-hidden="true">
      <circle cx="412" cy="236" r="34" fill="var(--accent)"/>
      <text x="412" y="248" text-anchor="middle" font-size="36" fill="var(--card)"
            font-family="IBM Plex Mono">1</text>
    </svg>
  </div>
  <figcaption>1 — the new filter; 2 — the count it updates.</figcaption>
</figure>
```

At most four callouts; each number is explained in the caption or the text right
below. Do not draw arrows across the screenshot — a number on the spot is enough.

**Terminal block.**

```html
<pre class="term"><span class="prompt">$ pnpm analyse silences --from 2026-10-25</span>
633 silences at sea, 352 vessels
…
report: docs/research/analysis/silences-2026-10-25.md</pre>
```

```css
.term{margin:0;padding:16px 20px;background:var(--card);border:1px solid var(--rule);
  border-radius:12px;font:14px/1.6 "IBM Plex Mono",monospace;color:var(--ink);overflow-x:auto}
.term .prompt{color:var(--accent)}
```

**Step-through and tabs.** Buttons that swap which of several `<figure>`s is visible.
Two rules: the page without a click must already make sense (show step 1, or the
"after" tab), and every view gets its own caption. The render check only sees the
default view, so open each one once by temporarily making it the default, render,
and look.

## Pitfalls

- **Secrets in a screenshot.** Tokens, e-mail addresses, customer names, internal
  URLs. Look at every pixel before embedding; crop or blur, and never publish a page
  with a credential in it.
- **Text too small to read.** A 1440-wide screenshot shown at 1080 is 75% size. Crop
  closer rather than shrinking a whole screen.
- **Retina blur.** Capture at twice the display size (`--force-device-scale-factor=2`)
  when the shot holds small text.
- **A map without the point.** Zoom so the subject fills the frame; a whole country
  with a 3-pixel track shows nothing.
