# Comparing and choosing — four diagram types

Read `svg-basis.md` first: canvas, tokens, arrowhead ids and the label-fitting rule live
there and are not repeated here.

Pick from this family when the reader has to **weigh** something: two situations, a set of
options, a division of work. These are also the staples of a management or consultancy
presentation — they read fast on a screen and survive being forwarded without you.

| Type | Pick it when you show |
|---|---|
| [Before and after](#before-and-after) | the same thing in two situations, and only the difference matters |
| [2×2 matrix](#22-matrix) | items positioned along two axes that each run from low to high |
| [Option cards](#option-cards) | two or three routes, judged on the same criteria |
| [Swimlanes](#swimlanes) | who does what, and when, across roles |

---

## Before and after

**Pick it when** something changed and the reader knows the old situation: a refactor, a
migration, a process that gained a step. **Not** when both sides are new to the reader —
then you are asking them to learn two things at once, and two separate pictures work
better.

**It must show** two structurally identical columns. The reader compares by position, so
anything that did not change stays in exactly the same spot, in `--rule`. Only the
difference gets `--accent`.

**Building blocks.** Two columns of 460px with 40px between them. A heading per column in
12px muted at the top. Rows 70px apart, one box per row per column, 460×54. Unchanged
rows: `--card` with a `--rule` border and muted text. Changed rows: accent border, ink
text. One vertical divider in `--rule` down the middle.

```html
<svg viewBox="0 0 1000 300" width="100%" style="height:auto;display:block" role="img"
     aria-label="Only the third step changed: the token check moved before the database call">
  <text x="20" y="30" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">before</text>
  <text x="520" y="30" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">after</text>
  <line x1="500" y1="44" x2="500" y2="280" stroke="var(--rule)" stroke-width="1.5"/>

  <rect x="20" y="50" width="460" height="54" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="40" y="82" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--muted)">1. request comes in</text>
  <rect x="520" y="50" width="460" height="54" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="540" y="82" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--muted)">1. request comes in</text>

  <rect x="20" y="120" width="460" height="54" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="40" y="152" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--muted)">2. read the database</text>
  <rect x="520" y="120" width="460" height="54" rx="8" fill="var(--accent)"
        fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="540" y="152" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">2. check the token</text>

  <rect x="20" y="190" width="460" height="54" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="40" y="222" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--muted)">3. check the token</text>
  <rect x="520" y="190" width="460" height="54" rx="8" fill="var(--accent)"
        fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="540" y="222" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">3. read the database</text>

  <text x="20" y="278" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">grey rows are unchanged</text>
</svg>
```

**Pitfalls.** Redrawing the right column in a different layout destroys the comparison —
identical geometry is the point. Highlighting everything is the same as highlighting
nothing; if more than half the rows changed, this is not a before-and-after but two
pictures.

---

## 2×2 matrix

**Pick it when** items differ along two independent dimensions that both run from low to
high: effort against impact, risk against reversibility, cost against value. **Not** when
one axis is a category rather than a scale — a position then means nothing, and a table
serves better.

**It must show** named axes with their direction, and items placed where their real values
put them. A quadrant name alone ("quick wins") without items in it says nothing.

**Building blocks.** A square field of 560×560 is too tall for the page; use 900×420 and
accept the stretch, or place the field left and a legend right. Four quadrant rectangles
in `--card` with `--rule` borders; the quadrant the page argues for gets `--accent` at
0.10. Axis labels in 12px muted, on the outside. Items are 7px accent circles with a 12px
label to the right, offset by 12px.

```html
<svg viewBox="0 0 1000 440" width="100%" style="height:auto;display:block" role="img"
     aria-label="Two changes are cheap and valuable; the rewrite is expensive with unclear value">
  <rect x="120" y="20" width="400" height="190" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <rect x="520" y="20" width="400" height="190" rx="8" fill="var(--accent)"
        fill-opacity="0.10" stroke="var(--accent)" stroke-width="1.5"/>
  <rect x="120" y="210" width="400" height="190" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <rect x="520" y="210" width="400" height="190" rx="8" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>

  <text x="140" y="44" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">expensive, valuable</text>
  <text x="540" y="44" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">cheap, valuable — do these first</text>
  <text x="140" y="234" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">expensive, little value</text>
  <text x="540" y="234" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">cheap, little value</text>

  <text x="20" y="120" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">value ↑</text>
  <text x="880" y="428" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">cheaper →</text>

  <circle cx="700" cy="110" r="7" fill="var(--accent)"/>
  <text x="716" y="115" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--ink)">cache the report query</text>

  <circle cx="800" cy="170" r="7" fill="var(--accent)"/>
  <text x="816" y="175" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--ink)">add the retry</text>

  <circle cx="220" cy="300" r="7" fill="var(--warn)"/>
  <text x="236" y="305" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--ink)">rewrite the import</text>
</svg>
```

**Pitfalls.** Both axes must point the same way — "cheaper →" and "value ↑" both improve
outward, so the good corner is unambiguous. Watch the right edge: a label at x=816 with 20
characters runs past x=980, so place items with long names on the left of their quadrant.

---

## Option cards

**Pick it when** a decision is open and two or three routes exist: build or buy, three
libraries, three migration strategies. **Not** when the choice has already been made —
then explain the chosen route and mention the alternatives in a sentence.

**It must show** the **same criteria in the same order** in every card. Comparison happens
by row, so a criterion missing from one card silently reads as "not applicable".

**Building blocks.** Three cards of 300px with 20px between them, or two of 470px. Header
strip 44px tall in `--accent` at 0.12 with the option name. Below it, one row per
criterion, 46px tall, separated by `--rule` lines: label in 12px muted on the left, value
in 13px ink on the right. Give the recommended card an accent border, the others `--rule`.

```html
<svg viewBox="0 0 1000 280" width="100%" style="height:auto;display:block" role="img"
     aria-label="Three routes compared on effort, risk and maintenance">
  <g>
    <rect x="20" y="20" width="300" height="240" rx="10" fill="var(--card)"
          stroke="var(--rule)" stroke-width="1.5"/>
    <rect x="20" y="20" width="300" height="44" rx="10" fill="var(--accent)"
          fill-opacity="0.12"/>
    <text x="40" y="48" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">buy</text>
    <line x1="20" y1="110" x2="320" y2="110" stroke="var(--rule)" stroke-width="1"/>
    <text x="40" y="92" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">effort</text>
    <text x="300" y="92" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">2 weeks</text>
    <line x1="20" y1="156" x2="320" y2="156" stroke="var(--rule)" stroke-width="1"/>
    <text x="40" y="138" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">risk</text>
    <text x="300" y="138" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">vendor lock-in</text>
    <text x="40" y="184" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">maintenance</text>
    <text x="300" y="184" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">theirs</text>
  </g>

  <g>
    <rect x="350" y="20" width="300" height="240" rx="10" fill="var(--card)"
          stroke="var(--accent)" stroke-width="2"/>
    <rect x="350" y="20" width="300" height="44" rx="10" fill="var(--accent)"
          fill-opacity="0.12"/>
    <text x="370" y="48" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">wrap an existing library</text>
    <line x1="350" y1="110" x2="650" y2="110" stroke="var(--rule)" stroke-width="1"/>
    <text x="370" y="92" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">effort</text>
    <text x="630" y="92" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">4 weeks</text>
    <line x1="350" y1="156" x2="650" y2="156" stroke="var(--rule)" stroke-width="1"/>
    <text x="370" y="138" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">risk</text>
    <text x="630" y="138" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">upstream changes</text>
    <text x="370" y="184" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">maintenance</text>
    <text x="630" y="184" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">shared</text>
    <text x="370" y="224" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--accent)">recommended</text>
  </g>

  <g>
    <rect x="680" y="20" width="300" height="240" rx="10" fill="var(--card)"
          stroke="var(--rule)" stroke-width="1.5"/>
    <rect x="680" y="20" width="300" height="44" rx="10" fill="var(--accent)"
          fill-opacity="0.12"/>
    <text x="700" y="48" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">build it ourselves</text>
    <line x1="680" y1="110" x2="980" y2="110" stroke="var(--rule)" stroke-width="1"/>
    <text x="700" y="92" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">effort</text>
    <text x="960" y="92" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">11 weeks</text>
    <line x1="680" y1="156" x2="980" y2="156" stroke="var(--rule)" stroke-width="1"/>
    <text x="700" y="138" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">risk</text>
    <text x="960" y="138" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">we own the bugs</text>
    <text x="700" y="184" font-family="IBM Plex Mono, monospace"
          font-size="12" fill="var(--muted)">maintenance</text>
    <text x="960" y="184" text-anchor="end" font-family="IBM Plex Mono, monospace"
          font-size="13" fill="var(--ink)">ours</text>
  </g>
</svg>
```

**Pitfalls.** Marking a recommendation without saying on which criterion it wins turns the
picture into an opinion. Values must be comparable: "2 weeks" against "quick" cannot be
weighed. Four options do not fit the width; drop the weakest and name it in the caption.

---

## Swimlanes

**Pick it when** several roles each do a part and the handover is the point: a review
process, an incident escalation, an onboarding. **Not** for technical components — lanes
say "someone is responsible here", which a queue is not.

**It must show** where work **crosses a lane**. Those crossings are where things stall,
and they are the reason to draw this instead of listing the steps.

**Building blocks.** Lanes are full-width bands, 80px tall, alternating `--card` and
`--card` with a light `--rule` fill line between them. Role name on the left in a 140px
column, 12px muted. Steps are 160×48 boxes positioned along an invisible time axis running
left to right. Handovers are arrows between lanes, in `--muted`.

```html
<svg viewBox="0 0 1000 290" width="100%" style="height:auto;display:block" role="img"
     aria-label="The developer opens the request, review bounces it back once, then it ships">
  <defs>
    <marker id="ar-lane" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <line x1="160" y1="20" x2="160" y2="270" stroke="var(--rule)" stroke-width="1.5"/>
  <line x1="20" y1="100" x2="980" y2="100" stroke="var(--rule)" stroke-width="1"/>
  <line x1="20" y1="180" x2="980" y2="180" stroke="var(--rule)" stroke-width="1"/>

  <text x="20" y="64" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">developer</text>
  <text x="20" y="144" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">reviewer</text>
  <text x="20" y="224" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">pipeline</text>

  <rect x="190" y="36" width="160" height="48" rx="8" fill="var(--card)"
        stroke="var(--accent)" stroke-width="1.5"/>
  <text x="270" y="64" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">open the PR</text>

  <path d="M270,84 L270,116" fill="none" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-lane)"/>

  <rect x="190" y="116" width="160" height="48" rx="8" fill="var(--card)"
        stroke="var(--accent)" stroke-width="1.5"/>
  <text x="270" y="144" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">read the diff</text>

  <path d="M350,140 L440,140 L440,60 L470,60" fill="none" stroke="var(--warn)"
        stroke-width="1.5" marker-end="url(#ar-lane)"/>
  <text x="356" y="162" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">changes asked</text>

  <rect x="480" y="36" width="160" height="48" rx="8" fill="var(--card)"
        stroke="var(--accent)" stroke-width="1.5"/>
  <text x="560" y="64" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">rework</text>

  <path d="M640,60 L700,60 L700,196 L740,196" fill="none" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-lane)"/>

  <rect x="750" y="196" width="160" height="48" rx="8" fill="var(--accent)"
        fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="830" y="224" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">deploy</text>
</svg>
```

**Pitfalls.** More than four lanes and the picture becomes taller than a screen — merge
roles that always act together. Steps in the same lane at the same x suggest simultaneity;
if they are sequential, move them apart horizontally. Colour the crossing that hurts with
`--warn`, and only that one.
