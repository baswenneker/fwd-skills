# SVG basis — the mechanics every diagram shares

Read this once per page, before you draw the first diagram. The four family files
(`diagrams-flow.md`, `diagrams-structure.md`, `diagrams-compare.md`,
`diagrams-numbers.md`) assume everything below and never repeat it. Colors, fonts and
widths come from Step 3 of `SKILL.md` — this file only says how to spend them inside an
`<svg>`.

## Canvas

Every diagram is one `<svg>` inside a card, and every card is the full 1080px page
width. Use a fixed coordinate system and let the browser scale it:

```html
<svg viewBox="0 0 1000 320" width="100%" style="height:auto;display:block"
     preserveAspectRatio="xMidYMid meet"
     role="img" aria-label="One sentence describing what the picture shows">
```

`height="auto"` as an *attribute* is not valid SVG — the picture then stretches to fill
whatever space it finds. The height must come from CSS, exactly as in the snippet above.

Work in that 1000-wide space: 20px of margin on the left and right, so the usable band
runs from x=20 to x=980. Pick the height from the content and keep it — never squeeze a
diagram by shortening the viewBox, because the labels do not shrink with it.

## Tokens only

Every `fill` and `stroke` is `var(--token)`. Six tokens exist:

| Token | Use it for |
|---|---|
| `--card` | the inside of a box |
| `--accent` | box borders, the emphasised element |
| `--muted` | arrows, arrow captions, axis lines |
| `--ink` | label text inside a box |
| `--rule` | lifelines, grid lines, dividers |
| `--warn` | exactly one element per page: the thing that can go wrong |

For a soft fill, do not invent a seventh color — reuse the accent at low opacity:
`fill="var(--accent)" fill-opacity="0.12"`. That holds in both themes, where a
hardcoded pale tint does not.

## Arrowheads

Each `<svg>` carries its own `<defs>` with an id nobody else uses. Shared ids across
several SVGs on one page resolve unpredictably, and you get arrows without heads.

```html
<defs>
  <marker id="ar-flow" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
  </marker>
</defs>
```

Name it after the diagram, not after the page: `ar-flow`, `ar-seq`, `ar-tree`,
`ar-pipe`. Then apply it with `marker-end="url(#ar-flow)"`.

## Text, and whether it fits

Two sizes, both from Step 3:

- **13px mono** for a label inside a box, `fill="var(--ink)"`.
- **12px mono** for an arrow caption or an axis label, `fill="var(--muted)"`.

Center a label with `text-anchor="middle"` at the box's center x, and put its baseline
about 4px below the box's center y — that reads as vertically centered.

SVG does not wrap text, so a label that is too long runs straight out of its box. IBM
Plex Mono is about **0.60 × the font size** per character, so at 13px each character
takes roughly 7.8px. Leave 12px of padding on each side:

```
usable characters ≈ (box width − 24) / 7.8
```

A 180px box therefore holds about 20 characters. Count before you draw. Longer label →
either widen the box, or split it over two `<text>` elements 16px apart, never a smaller
font.

## Caption

Below every `<svg>`, one sentence in 12-13px saying what the reader should notice —
not what the picture is. "The token is checked before anything reaches the database",
not "Diagram of the login flow".

## Before you move on

1. Does every element explain something? A box that only decorates goes out.
2. Does the arrowhead id exist exactly once on the page?
3. Does the longest label fit its box by the character count above?
4. Are all colors tokens, so the picture survives the dark theme?
5. Is the label language the page's language, without mixing?
