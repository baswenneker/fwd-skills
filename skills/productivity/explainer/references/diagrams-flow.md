# Flow and time — four diagram types

Read `svg-basis.md` first: canvas, tokens, arrowhead ids and the label-fitting rule live
there and are not repeated here.

Pick from this family when the subject has an **order**: something happens, then
something else.

| Type | Pick it when you show |
|---|---|
| [Flowchart](#flowchart) | steps that branch on a condition |
| [Sequence diagram](#sequence-diagram) | who calls whom, in what order |
| [Timeline](#timeline) | what happens when, over calendar time |
| [State diagram](#state-diagram) | which states a thing can be in, and what moves it |

---

## Flowchart

**Pick it when** a path forks: a check, a retry, an error branch. **Not** when every step
follows the previous one unconditionally — that is a pipeline (see
`diagrams-structure.md`) and a straight chain of boxes reads better.

**It must show** at least one decision with both outcomes labelled. A flowchart without a
fork is a list wearing a costume.

**Building blocks.** Rounded rectangle = a step, 180×60 with `rx="10"`. Diamond = a
decision, 200 wide by 100 tall, drawn as a `<path>` through its four points. Arrows
horizontal at the row's center y; a branch leaves the diamond's top or bottom point.
Every branch arrow carries a caption ("yes" / "no", or the actual condition).

```html
<svg viewBox="0 0 1000 210" width="100%" style="height:auto;display:block" role="img"
     aria-label="A request is checked for a valid token before it reaches the database">
  <defs>
    <marker id="ar-flow" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <rect x="20" y="40" width="180" height="60" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="110" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">request in</text>

  <line x1="200" y1="70" x2="292" y2="70" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-flow)"/>

  <path d="M400,20 L500,70 L400,120 L300,70 z"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="400" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">token valid?</text>

  <line x1="500" y1="70" x2="592" y2="70" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-flow)"/>
  <text x="546" y="60" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">yes</text>

  <rect x="600" y="40" width="180" height="60" rx="10"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="690" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">read database</text>

  <path d="M400,120 L400,162 L600,162" fill="none" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-flow)"/>
  <text x="470" y="154" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">no</text>

  <rect x="600" y="132" width="180" height="60" rx="10"
        fill="var(--card)" stroke="var(--warn)" stroke-width="1.5"/>
  <text x="690" y="166" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">401, stop</text>
</svg>
```

**Pitfalls.** An unlabelled branch forces the reader to guess which side is which.
Diagonal arrows between rows look tangled — route them as elbows (`L` segments at right
angles), as in the "no" path above. More than seven boxes: split the picture, or fold a
sub-flow into one box and draw it separately.

---

## Sequence diagram

**Pick it when** the point is the **order of messages** between two or more parties: a
login handshake, a webhook round trip, a retry with a queue in between. **Not** for
showing what the parts are — that is an architecture picture.

**It must show** time running downward, one lifeline per participant, and every message
labelled with what is actually sent.

**Building blocks.** A header box per participant at the top (160×40, `rx="8"`), evenly
spaced across the band. From each header's bottom edge a dashed lifeline in `--rule` down
to the bottom. Messages are horizontal arrows between lifelines, caption 10px above the
line. A reply goes back with `stroke-dasharray="5 4"`. An activation bar — the period a
participant is busy — is a 12px-wide rect on the lifeline, `--accent` at 0.18 opacity.

**Notes.** A note says what one participant does *by itself*: "thinks for 20 seconds",
"reads the last turn", "the user types". That is not a message, so it must not look like
one — no arrow, no box. Write it as 12px muted text with a thin 1px `--rule` tick to its
left, 12px before the text, spanning the rows it covers. Place it in the gap to the right
of the lifeline it belongs to, on a row where no arrow crosses. If every row there is
taken, keep the right margin free as a note column and name the participant in the note
itself.

Notes are where a sequence diagram earns its keep: without them a reader sees three fast
arrows and misses that the middle step takes twenty seconds. Add one wherever the waiting,
the thinking or the storing is the actual point.

```html
<svg viewBox="0 0 1000 330" width="100%" style="height:auto;display:block" role="img"
     aria-label="The browser asks the API, which asks the database; the query itself takes about 900 milliseconds">
  <defs>
    <marker id="ar-seq" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <rect x="40" y="20" width="160" height="40" rx="8"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="120" y="45" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">browser</text>
  <line x1="120" y1="60" x2="120" y2="310" stroke="var(--rule)"
        stroke-width="1.5" stroke-dasharray="4 5"/>

  <rect x="340" y="20" width="160" height="40" rx="8"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="420" y="45" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">API</text>
  <line x1="420" y1="60" x2="420" y2="310" stroke="var(--rule)"
        stroke-width="1.5" stroke-dasharray="4 5"/>

  <rect x="640" y="20" width="160" height="40" rx="8"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="720" y="45" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">database</text>
  <line x1="720" y1="60" x2="720" y2="310" stroke="var(--rule)"
        stroke-width="1.5" stroke-dasharray="4 5"/>

  <line x1="120" y1="110" x2="412" y2="110" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-seq)"/>
  <text x="266" y="100" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">GET /report/42</text>

  <rect x="414" y="110" width="12" height="90" fill="var(--accent)"
        fill-opacity="0.18" stroke="var(--accent)" stroke-width="1"/>

  <line x1="426" y1="150" x2="712" y2="150" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-seq)"/>
  <text x="569" y="140" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">select rows</text>

  <line x1="712" y1="190" x2="434" y2="190" stroke="var(--muted)" stroke-width="1.5"
        stroke-dasharray="5 4" marker-end="url(#ar-seq)"/>
  <text x="573" y="180" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">42 rows</text>

  <line x1="752" y1="140" x2="752" y2="200" stroke="var(--rule)" stroke-width="1.5"/>
  <text x="764" y="166" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">scans 2.1M rows,</text>
  <text x="764" y="184" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">takes about 900 ms</text>

  <line x1="414" y1="250" x2="128" y2="250" stroke="var(--muted)" stroke-width="1.5"
        stroke-dasharray="5 4" marker-end="url(#ar-seq)"/>
  <text x="271" y="240" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">JSON, 200</text>

  <line x1="136" y1="272" x2="136" y2="300" stroke="var(--rule)" stroke-width="1.5"/>
  <text x="148" y="291" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">the browser draws the table</text>
</svg>
```

### Comparing two routes

A sequence diagram also answers "should we do it in one call or two?". Draw the routes as
**two sequence diagrams with the same participants in the same positions**, each with its
own heading above it: "Option A — two separate calls", "Option B — one call". The reader
then compares by counting arrows and reading the notes, which is exactly the comparison
that matters: fewer round trips, or less waiting.

Two rules keep it honest. Keep the lifelines at identical x positions in both pictures, so
the eye can jump between them. And put the same notes in both, with their real numbers —
if option A waits twenty seconds and option B waits two, that difference is the whole
answer and it lives in the notes, not in the arrows.

If the comparison is not about the order of messages but about effort, risk or cost, use
option cards instead — see `diagrams-compare.md`.

**Pitfalls.** More than four participants and the lifelines crowd; merge two into one, or
split the exchange into two pictures. Messages need 40px of vertical space each, so count
the rows before you set the height. A caption sitting on the arrow instead of above it
becomes unreadable in the dark theme. A note drawn in a box reads as a participant — keep
it as bare text with its tick.

---

## Timeline

**Pick it when** calendar time matters: a rollout, a migration, a project with phases.
**Not** when only the order matters and the dates do not — use a flowchart, which does not
suggest a duration that is not real.

**It must show** a scale the reader can measure against: months, sprints, quarters. Bars
whose length means nothing are decoration.

**Building blocks.** One horizontal axis in `--rule` across the band, with tick labels in
12px muted. Phases are bars 28px tall, `--accent` at 0.15 opacity with an accent border,
positioned and sized by date. Milestones are 6px circles on the axis, label alternating
above and below so they never collide.

```html
<svg viewBox="0 0 1000 220" width="100%" style="height:auto;display:block" role="img"
     aria-label="The migration runs over three quarters, with the cutover at the end of Q3">
  <line x1="20" y1="150" x2="980" y2="150" stroke="var(--rule)" stroke-width="1.5"/>

  <text x="20" y="176" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">Q1</text>
  <text x="340" y="176" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">Q2</text>
  <text x="660" y="176" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">Q3</text>

  <rect x="20" y="60" width="300" height="28" rx="6" fill="var(--accent)"
        fill-opacity="0.15" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="34" y="79" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">write shadow copies</text>

  <rect x="340" y="100" width="620" height="28" rx="6" fill="var(--accent)"
        fill-opacity="0.15" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="354" y="119" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">read from the new store</text>

  <circle cx="960" cy="150" r="6" fill="var(--warn)"/>
  <text x="960" y="200" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">cutover</text>
</svg>
```

**Pitfalls.** Bars that all start at the left teach nothing — the horizontal position is
the information. Never label a milestone with a bare date; give it its subject ("cutover,
30 Sept"). If phases overlap in time, stack them on separate rows rather than shortening
one to fit.

---

## State diagram

**Pick it when** a thing sits in one of a few named states and something moves it between
them: an order, a deploy, a session, a feature flag. **Not** for a linear process — states
imply you can come back, and a flowchart says it better if you cannot.

**It must show** every transition labelled with its trigger, and the starting state marked.

**Building blocks.** Rounded rectangle per state, 160×54, `rx="27"` so it reads as a pill
rather than a step. A small filled 7px circle marks the start, with a short arrow into the
first state. Transitions are curved paths (`M … Q …`) so a forward and a backward arrow
between the same pair do not overlap. The trigger label sits at the curve's apex.

```html
<svg viewBox="0 0 1000 250" width="100%" style="height:auto;display:block" role="img"
     aria-label="An order moves from new to paid to shipped, or is cancelled while still new">
  <defs>
    <marker id="ar-state" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <circle cx="34" cy="70" r="7" fill="var(--accent)"/>
  <line x1="41" y1="70" x2="92" y2="70" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-state)"/>

  <rect x="100" y="43" width="160" height="54" rx="27"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="180" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">new</text>

  <path d="M260,60 Q360,20 452,60" fill="none" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-state)"/>
  <text x="356" y="26" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">payment confirmed</text>

  <rect x="460" y="43" width="160" height="54" rx="27"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="540" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">paid</text>

  <path d="M620,70 L712,70" fill="none" stroke="var(--muted)"
        stroke-width="1.5" marker-end="url(#ar-state)"/>
  <text x="666" y="60" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">picked</text>

  <rect x="720" y="43" width="160" height="54" rx="27"
        fill="var(--card)" stroke="var(--accent)" stroke-width="1.5"/>
  <text x="800" y="74" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">shipped</text>

  <path d="M180,97 Q300,200 452,187" fill="none" stroke="var(--muted)"
        stroke-width="1.5" stroke-dasharray="5 4" marker-end="url(#ar-state)"/>
  <text x="300" y="207" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="12" fill="var(--muted)">cancelled within 24h</text>

  <rect x="460" y="160" width="160" height="54" rx="27"
        fill="var(--card)" stroke="var(--warn)" stroke-width="1.5"/>
  <text x="540" y="191" text-anchor="middle" font-family="IBM Plex Mono, monospace"
        font-size="13" fill="var(--ink)">cancelled</text>
</svg>
```

**Pitfalls.** A transition without a trigger is the most common mistake — the reader then
cannot tell what causes the move. Two straight lines between the same pair of states
overlap; curve them apart, one above and one below. Keep it to five states; beyond that,
group them and draw the group separately.
