---
name: fwd:issue-create
description: Interactief een GitHub issue opstellen volgens een vast 5-secties template (probleem, voorbeelden, bevindingen, potentiële oplossing, tests). Skill leest input uit een argument óf de huidige conversatie-context, detecteert bestaande repo-labels, vraagt om een assignee, en laat de gebruiker de complete draft per sectie reviewen voordat `gh issue create` wordt aangeroepen. Use when user wants to create a GitHub issue from a problem they are describing, runs `/fwd:issue-create`, says "maak een issue", or "create issue from context".
argument-hint: <vrije tekst beschrijving van probleem (optioneel — anders huidige context)>
---

# fwd:issue-create

Interactieve issue-creatie met een vast template en één review-ronde voordat de issue wordt opgevoerd.

**Wat dit doet:** input verzamelen → GitHub-metadata probet (labels, assignees) → een 5-secties draft bouwen → de gebruiker laat reviewen → `rtk gh issue create` aanroepen.

**Wat dit NIET doet:** issues automatisch opvoeren zonder bevestiging, de gebruiker spammen met popup-vragen per sectie, of bestaande issues sluiten/labelen.

## Per-skill flow

### 1. Gather input

- **Met argument** (`/fwd:issue-create <vrije tekst>`) → gebruik die tekst als basis voor het probleem.
- **Zonder argument** → gebruik de huidige conversatie-context: recente bug-discussies, foutmeldingen, code die je hebt gelezen, beslissingen die voorbij kwamen. Vat dat zelf samen tot één probleemstelling.

Als de context te dun is om iets zinnigs te schrijven (geen argument én geen relevante context in de laatste turns), vraag éénmaal aan de gebruiker om de probleemstelling in één zin te bevestigen voordat je verder bouwt.

### 2. GH meta probe

```
bash "${CLAUDE_SKILL_DIR}/scripts/probe-meta.sh"
```

Stdout is een JSON-blob:

```json
{"labels":[{"name":"bug","description":"..."}, ...],"assignees":["alice","bas",...]}
```

Bij non-zero exit (gh niet geauthenticeerd, niet in een git-repo, geen remote): rapporteer de stderr-regel en stop de skill. Probeer niet zelf `gh auth login` te draaien.

### 3. Draft + suggesties

Bouw een complete draft met deze 5 secties als `##`-headers:

1. **Probleem** — wat gaat er mis / wat ontbreekt er. 2-4 zinnen.
2. **Voorbeelden** — concrete reproductie, scenarios, codefragmenten. Liefst direct kopieerbaar (codeblocks).
3. **Bevindingen** — wat is al onderzocht. Verwijs naar relevante bestanden + regels als `path/to/file.ts:42`.
4. **Potentiële oplossing** — voorgestelde aanpak op hoofdlijnen. Niet de implementatie, wel de richting + één alternatief als dat zinnig is.
5. **Tests** — concrete unit / integration / E2E tests die het gedrag moeten verifiëren. Eén of meer per niveau; benoem welke bestanden / suites geraakt worden.

**Title:** afgeleid uit het probleem, ≤72 chars, geen conventional-commit prefix (`fix:` / `feat:` etc.) — dat hoort op de commit, niet op de issue.

**Labels:** uit `labels` in de probe-output, kies 1-3 die inhoudelijk matchen op de draft (vergelijk met `name` + `description`). Toon de gekozen labels expliciet in de draft-header.

**Assignee:** default `@me` (de gebruiker, dus zichzelf). Toon de andere `assignees` uit de probe-output als alternatief in de draft-header, zodat de user kan zeggen "assign aan alice" tijdens review.

### 4. Review-ronde (één keer)

Toon de complete draft in dit format als één bericht:

````markdown
## Concept-issue (review)

**Title:** <title>
**Labels:** <label1>, <label2>
**Assignee:** <login>
**Andere assignable users:** <login1>, <login2>, …

---

## 1. Probleem
<content>

## 2. Voorbeelden
<content>

## 3. Bevindingen
<content>

## 4. Potentiële oplossing
<content>

## 5. Tests
<content>

---

Reageer per sectie met **"ok"** of een wijzigingsinstructie. Schrijf **"annuleer"** om te stoppen zonder issue aan te maken.
````

Verwerk het antwoord:

- **"ok" / geen wijzigingen** → door naar stap 5.
- **Wijzigingsinstructies** (per sectie of voor title / labels / assignee) → pas aan en toon de aangepaste draft één keer terug. Vraag dan om finale bevestiging ("ok om op te voeren?"). Maximaal één regeneratie-ronde — daarna forceer ja/nee.
- **"annuleer" / "stop"** → stop zonder `gh issue create` aan te roepen. Bevestig dat er niets is opgevoerd.

### 5. Issue opvoeren

Schrijf de body (de 5 secties) naar een tijdelijk bestand om quoting-problemen te vermijden:

```bash
BODY_FILE=$(mktemp)
cat > "$BODY_FILE" <<'EOF'
## 1. Probleem
…

## 2. Voorbeelden
…

## 3. Bevindingen
…

## 4. Potentiële oplossing
…

## 5. Tests
…
EOF

rtk gh issue create \
  --title "<title>" \
  --body-file "$BODY_FILE" \
  --label "<label1>" --label "<label2>" \
  --assignee "<login>"

rm -f "$BODY_FILE"
```

Stdout is de issue-URL — toon die aan de gebruiker. Als `gh issue create` faalt: toon de error en stop. Geen retry — laat de gebruiker eerst `gh auth status` / repo-permissies checken.

## Boundaries

- **Eén invocation = één issue.** Geen batch-creatie.
- **Geen popup-vragen per sectie.** Review is inline vrije tekst (zie stap 4); AskUserQuestion is alleen toegestaan als de input écht te dun is in stap 1.
- **Geen autonome run.** Skill stopt altijd op user-confirmatie vóór `rtk gh issue create`.
- **Geen retry op create-failure.** Toon de error, stop.
- **Geen AI-attribution.** De issue-body bevat geen "Generated with Claude Code" footer of `Co-Authored-By: Claude` regel.
- **Geen mutatie van bestaande issues.** Skill maakt alleen aan; voor labels/comments/close zijn aparte tools nodig.
