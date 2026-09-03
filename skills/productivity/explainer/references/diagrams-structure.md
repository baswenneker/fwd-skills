# Structure and composition — four diagram types

Read `svg-basis.md` first: canvas, tokens, arrowhead ids and the label-fitting rule live
there and are not repeated here.

Pick from this family when the subject has a **shape**: what consists of what, and what
touches what. Time plays no role here — if it does, use `diagrams-flow.md`.

| Type | Pick it when you show |
|---|---|
| [Architecture picture](#architecture-picture) | which parts talk to each other, across which boundary |
| [Layer model](#layer-model) | what sits inside what, from top to bottom |
| [Tree](#tree) | a breakdown: folders, modules, an organisation |
| [Pipeline](#pipeline) | input, transformation, output, with the data shape per stage |

---

## Architecture picture

**Pick it when** the reader needs to know which components exist and who speaks to whom:
a service landscape, a plugin and its host, a browser plus API plus queue. **Not** when
the order of the messages is the point — that is a sequence diagram.

**It must show** at least one **boundary**: the network, the machine, the trust border.
Boxes without a boundary say nothing that a bullet list does not already say.

**Building blocks.** Component = rounded rectangle 200×70, `rx="10"`. A boundary is a
dashed rectangle in `--rule` around a group, with its name in 12px muted in the top-left
corner, 14px inside the edge. Connections are lines in `--muted` with a caption naming the
protocol or the payload ("HTTPS", "JSON over the queue").

```html
<svg viewBox="0 0 1000 300" width="100%" style="height:auto;display:block" role="img"
     aria-label="The browser reaches the API over HTTPS; inside the cloud boundary the API uses the queue and the database">
  <defs>
    <marker id="ar-arch" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <rect x="380" y="30" width="600" height="250" rx="14" fill="none"
        stroke="var(--rule)" stroke-width="1.5" stroke-dasharray="6 5"/>
  <text x="394" y="52" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">Azure subscription</text>

  <rect x="20" y="115" width="200" height="70" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="120" y="154" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">browser</text>

  <line x1="220" y1="150" x2="412" y2="150" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-arch)"/>
  <text x="316" y="140" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">HTTPS</text>

  <rect x="420" y="115" width="200" height="70" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="520" y="154" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">API container</text>

  <line x1="620" y1="135" x2="752" y2="95" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-arch)"/>
  <text x="686" y="102" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">jobs</text>

  <rect x="760" y="60" width="200" height="70" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="860" y="99" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">queue</text>

  <line x1="620" y1="165" x2="752" y2="205" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-arch)"/>
  <text x="686" y="200" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">SQL</text>

  <rect x="760" y="170" width="200" height="70" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="860" y="209" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">database</text>
</svg>
```

**Pitfalls.** An unlabelled line between two boxes is the weakest element in any
explainer: the reader cannot tell a call from a copy from a shared file. More than six
components and the lines cross — draw the whole at a coarse level, then one component's
inside separately.

---

## Layer model

**Pick it when** something is stacked or nested: a stack of libraries, a plugin over a
host, an abstraction over a raw interface. **Not** when the parts sit next to each other
as peers — layers claim that the one above depends on the one below.

**It must show** the direction of the dependency, and per layer what it adds that the
layer below does not have.

**Building blocks.** Full-width bars, 56px tall, stacked with 10px between them, top layer
at the top. Name in 13px ink on the left at x+20, one short note in 12px muted on the
right, right-aligned at x=940. Emphasise the layer the page is about with `--accent` at
0.12 opacity; leave the others `--card`.

```html
<svg viewBox="0 0 1000 250" width="100%" style="height:auto;display:block" role="img"
     aria-label="The skill sits on top of Claude Code, which sits on the model">
  <rect x="20" y="20" width="940" height="56" rx="10" fill="var(--accent)"
        fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="40" y="54" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">the skill</text>
  <text x="940" y="54" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">adds the working method</text>

  <rect x="20" y="86" width="940" height="56" rx="10" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="40" y="120" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">Claude Code</text>
  <text x="940" y="120" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">adds tools and permissions</text>

  <rect x="20" y="152" width="940" height="56" rx="10" fill="var(--card)"
        stroke="var(--rule)" stroke-width="1.5"/>
  <text x="40" y="186" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">the model</text>
  <text x="940" y="186" text-anchor="end" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">reads and writes text</text>

  <text x="20" y="232" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">each layer uses only the one directly below it</text>
</svg>
```

**Pitfalls.** Layers of unequal height suggest an importance that is not there — keep them
identical. A layer without a note is a label, not an explanation. If two things really are
peers, put them side by side within one layer instead of stacking them.

---

## Tree

**Pick it when** something breaks down into parts that break down again: a repository, a
menu, a decomposition of a goal into features. **Not** for a network — a tree claims every
node has exactly one parent.

**It must show** the depth clearly, and per level what the level means ("skill" → "file").

**Building blocks.** Node = rectangle 200×48, `rx="8"`. Levels 90px apart vertically.
Connectors are elbows, never diagonals: from the parent's bottom edge straight down half
the gap, sideways, then down into the child. Draw each as one `<path>` with `L` segments.

```html
<svg viewBox="0 0 1000 260" width="100%" style="height:auto;display:block" role="img"
     aria-label="The skill folder holds a SKILL.md and a references folder with four files">
  <rect x="400" y="20" width="200" height="48" rx="8"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="500" y="48" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">explainer/</text>

  <path d="M500,68 L500,92 L200,92 L200,110" fill="none"
        stroke="var(--rule)" stroke-width="1.5"/>
  <path d="M500,68 L500,92 L700,92 L700,110" fill="none"
        stroke="var(--rule)" stroke-width="1.5"/>

  <rect x="100" y="110" width="200" height="48" rx="8"
        fill="var(--card)" stroke="var(--rule)" stroke-width="1.5"/>
  <text x="200" y="138" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">SKILL.md</text>

  <rect x="600" y="110" width="200" height="48" rx="8"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="700" y="138" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">references/</text>

  <path d="M700,158 L700,182 L560,182 L560,200" fill="none"
        stroke="var(--rule)" stroke-width="1.5"/>
  <path d="M700,158 L700,182 L840,182 L840,200" fill="none"
        stroke="var(--rule)" stroke-width="1.5"/>

  <rect x="460" y="200" width="200" height="48" rx="8"
        fill="var(--card)" stroke="var(--rule)" stroke-width="1.5"/>
  <text x="560" y="228" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">svg-basis.md</text>

  <rect x="740" y="200" width="200" height="48" rx="8"
        fill="var(--card)" stroke="var(--rule)" stroke-width="1.5"/>
  <text x="840" y="228" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">diagrams-flow.md</text>
</svg>
```

**Pitfalls.** Trees grow wide fast: at 200px per node, one level holds four nodes at most.
Beyond that, show one branch in full and summarise the siblings in a single box ("+ 3
more"). Diagonal connectors read as a network — always use elbows.

---

## Pipeline

**Pick it when** data changes form as it travels: raw text becomes chunks becomes vectors,
or a log line becomes a metric. **Not** when a step can fail into a different path — that
fork makes it a flowchart.

**It must show** the **data shape at each stage**, not just the name of the step. That
shape is the whole reason to draw this rather than write a sentence.

**Building blocks.** Stages as chevrons: a `<path>` 220 wide and 70 tall with a 20px point
on the right, so the direction is in the form itself and needs no arrows. Under each
stage, the data shape in 12px muted. A small number above each stage helps the caption
refer back to it.

```html
<svg viewBox="0 0 1000 190" width="100%" style="height:auto;display:block" role="img"
     aria-label="A document becomes chunks, then vectors, then rows in the index">
  <path d="M20,40 L220,40 L240,75 L220,110 L20,110 z"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="120" y="80" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">split</text>
  <text x="120" y="136" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">1 PDF → 240 chunks</text>

  <path d="M260,40 L460,40 L480,75 L460,110 L260,110 L280,75 z"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="374" y="80" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">embed</text>
  <text x="374" y="136" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">240 vectors, 1536 wide</text>

  <path d="M500,40 L700,40 L720,75 L700,110 L500,110 L520,75 z"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="614" y="80" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">index</text>
  <text x="614" y="136" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">240 rows, searchable</text>

  <path d="M740,40 L940,40 L960,75 L940,110 L740,110 L760,75 z"
        fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="854" y="80" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">search</text>
  <text x="854" y="136" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">question → top 5</text>
</svg>
```

**Pitfalls.** A stage label without a data shape underneath turns this into a row of
boxes. Real numbers beat placeholders: "240 chunks" teaches, "many chunks" does not. Four
stages fit the width; a fifth means shrinking the boxes, and the labels stop fitting.
