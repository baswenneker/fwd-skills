# Numbers — three diagram types

Read `svg-basis.md` first: canvas, tokens, arrowhead ids and the label-fitting rule live
there and are not repeated here.

Pick from this family when the point is a **quantity**: how much, how many, what share.
One rule governs all three: **the length or width of a shape must be proportional to the
number it represents.** A bar that is 10% longer for a value that is 300% higher is worse
than no picture, because the reader believes the shape before they read the label.

Always write the actual number next to the shape. The picture gives the comparison, the
number gives the fact.

| Type | Pick it when you show |
|---|---|
| [Bar chart](#bar-chart) | a few quantities side by side |
| [Funnel](#funnel) | many becoming few, with the loss per step |
| [Distribution](#distribution) | one whole divided into shares |

---

## Bar chart

**Pick it when** you compare between three and eight quantities that share a unit:
durations, counts, sizes. **Not** for a trend over time — that is a line, and this skill's
subjects rarely need one; a timeline usually serves better.

**It must show** the zero point. Bars that start somewhere else exaggerate the difference,
and a reader who spots it stops trusting the whole page.

**Building blocks.** Horizontal bars, so long labels have room. Label column 240px wide on
the left, bars starting at x=260, the axis running to x=900, leaving room for the value at
the bar's end. Bars 34px tall, 18px apart. Scale: `bar width = value / max × 640`. Value in
13px mono at the bar's end plus 12px, `tabular-nums`.

```html
<svg viewBox="0 0 1000 200" width="100%" style="height:auto;display:block" role="img"
     aria-label="The database call takes nine times as long as everything else together">
  <line x1="260" y1="20" x2="260" y2="180" stroke="var(--rule)" stroke-width="1.5"/>

  <text x="240" y="45" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">database call</text>
  <rect x="260" y="24" width="640" height="34" rx="6" fill="var(--accent)"
        fill-opacity="0.85" stroke="none"/>
  <text x="912" y="46" font-family="IBM Plex Mono, monospace" font-size="13"
        fill="var(--ink)" style="font-variant-numeric:tabular-nums">1840 ms</text>

  <text x="240" y="97" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">template render</text>
  <rect x="260" y="76" width="52" height="34" rx="6" fill="var(--accent)"
        fill-opacity="0.35" stroke="none"/>
  <text x="324" y="98" font-family="IBM Plex Mono, monospace" font-size="13"
        fill="var(--ink)" style="font-variant-numeric:tabular-nums">150 ms</text>

  <text x="240" y="149" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">token check</text>
  <rect x="260" y="128" width="17" height="34" rx="6" fill="var(--accent)"
        fill-opacity="0.35" stroke="none"/>
  <text x="289" y="150" font-family="IBM Plex Mono, monospace" font-size="13"
        fill="var(--ink)" style="font-variant-numeric:tabular-nums">48 ms</text>
</svg>
```

**Pitfalls.** Do not give every bar its own colour — one accent, and a heavier opacity for
the bar the text is about. A bar shorter than about 8px disappears; keep a minimum width
and let the number carry the meaning. Sort by size unless a fixed order (steps, months) is
itself the information.

---

## Funnel

**Pick it when** a population shrinks along a path: visitors to buyers, candidates to
hires, requests to successful responses. **Not** when nothing is lost between the steps —
a pipeline (`diagrams-structure.md`) fits a transformation without loss.

**It must show** the loss per step, as a number and as a percentage. A funnel without the
drop-off is a decorative pipeline.

**Building blocks.** Stacked trapezoids, each 56px tall with 14px between them, width
proportional to the count and centred on x=500. Pick a top width (700 works) for the first
count, then every other width is `count / first count × 700`. Draw each as a `<path>`
through four points: top-left, top-right, bottom-right, bottom-left, where the bottom width
equals the next step's top width. The last step has no next step, so it is a rectangle. Count in 13px ink inside; the drop in 12px `--warn` to the right of
the shape.

```html
<svg viewBox="0 0 1000 270" width="100%" style="height:auto;display:block" role="img"
     aria-label="Of a thousand visitors, a hundred and eighty finish the purchase">
  <path d="M150,20 L850,20 L647,76 L353,76 z"
        fill="var(--accent)" fill-opacity="0.30" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="500" y="54" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">1000 visitors</text>

  <path d="M353,90 L647,90 L563,146 L437,146 z"
        fill="var(--accent)" fill-opacity="0.30" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="500" y="124" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">420 in the cart</text>
  <text x="680" y="124" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--warn)">−580 (58%)</text>

  <path d="M437,160 L563,160 L563,216 L437,216 z"
        fill="var(--accent)" fill-opacity="0.30" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="500" y="194" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">180 paid</text>
  <text x="680" y="194" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--warn)">−240 (57%)</text>

  <text x="20" y="250" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">each shape is as wide as its count: 700px for 1000, 294px for 420, 126px for 180</text>
</svg>
```

**Pitfalls.** Widths must follow the counts, not look tidy: 420 out of 1000 is 42% of the
top width, not "a bit narrower". Work the widths out before you draw — a funnel that looks
right but lies is worse than a table. A label inside a narrow bottom step will not fit; put
it to the right rather than shrink the font. Four steps is the practical maximum, and a
last step under about 8% of the first becomes a sliver — say the number in the caption
instead.

---

## Distribution

**Pick it when** one whole splits into parts and the shares are the point: where the time
goes, what the bill consists of, which categories the errors fall into. **Not** for
comparing separate things that are not part of one whole — that is a bar chart.

**It must show** that the parts add up to the whole, and it must name the whole. "68% of
what?" is the failure this picture exists to prevent.

**Building blocks.** One horizontal bar 60px tall across the full band, split into
segments whose widths are `share × 940`. Segments in `--accent` at descending opacity
(0.85, 0.55, 0.35, 0.18), separated by 2px gaps in the page background. A legend below in
two columns: a 10px colour square, the name in 13px ink, the share in 12px muted. Put the
label inside a segment only when it is wider than about 120px.

```html
<svg viewBox="0 0 1000 190" width="100%" style="height:auto;display:block" role="img"
     aria-label="Of 1840 milliseconds, the query itself takes two thirds">
  <text x="20" y="30" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">1840 ms per request, split by stage</text>

  <rect x="20" y="44" width="620" height="60" rx="6" fill="var(--accent)"
        fill-opacity="0.85"/>
  <text x="40" y="80" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--card)">the query</text>

  <rect x="644" y="44" width="188" height="60" fill="var(--accent)" fill-opacity="0.55"/>
  <text x="664" y="80" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">serialise</text>

  <rect x="836" y="44" width="124" height="60" rx="6" fill="var(--accent)"
        fill-opacity="0.30"/>

  <rect x="20" y="128" width="10" height="10" fill="var(--accent)" fill-opacity="0.85"/>
  <text x="40" y="138" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">the query</text>
  <text x="180" y="138" font-family="IBM Plex Mono, monospace" font-size="12"
        fill="var(--muted)" style="font-variant-numeric:tabular-nums">1210 ms · 66%</text>

  <rect x="360" y="128" width="10" height="10" fill="var(--accent)" fill-opacity="0.55"/>
  <text x="380" y="138" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">serialise</text>
  <text x="520" y="138" font-family="IBM Plex Mono, monospace" font-size="12"
        fill="var(--muted)" style="font-variant-numeric:tabular-nums">368 ms · 20%</text>

  <rect x="700" y="128" width="10" height="10" fill="var(--accent)" fill-opacity="0.30"/>
  <text x="720" y="138" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">the rest</text>
  <text x="860" y="138" font-family="IBM Plex Mono, monospace" font-size="12"
        fill="var(--muted)" style="font-variant-numeric:tabular-nums">262 ms · 14%</text>
</svg>
```

**Pitfalls.** Never draw a pie: the artifact viewer scales it down, and comparing angles is
harder than comparing lengths. Text inside the darkest segment needs `--card` as its fill,
not `--ink`, or it disappears in the light theme. Five segments or more become slivers —
merge the small ones into "the rest" and name them in the caption.
