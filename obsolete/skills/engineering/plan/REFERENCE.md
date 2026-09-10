# fwd:plan — REFERENCE

Uitvoeringsdetail dat niet in elke sessie geladen hoeft: de check-modus-procedure. De ingang + disambiguatie (wanneer is een argument check-modus, wanneer een gewoon plan-doel) staat in SKILL.md §Check-modus.

## Check-modus — procedure

**Zonder slug** (`/fwd:plan check`): lijst de contracten in `.claude/plan-contracts/` (`ls`) en stop. De gebruiker kiest er één.

**Met slug** (`/fwd:plan check <slug>`): lees het contract. Bestaan er gesuffixte varianten (`<slug>-2.md`, …): kies de nieuwste (hoogste N) of vraag de gebruiker welke — toets nooit stilzwijgend het verouderde `<slug>.md` als er een nieuwer contract naast ligt. (Randgeval: na het opvullen van een suffix-gat kan het hoogste N ouder zijn — check bij twijfel de "Vastgelegd:"-datum.) Toets dan:

1. **Diff-toets.** Bouw de lijst geraakte bestanden uit twee bronnen (rtk vervuilt output — filter dus):
   - Tracked wijzigingen sinds de basis-commit: `rtk git diff --name-only <basis-commit> -- . ':(exclude).claude/plan-contracts' 2>/dev/null | grep -vE '^(ok|Changes:|[[:space:]]*)$'` — de `:(exclude)`-pathspec houdt het contract zelf eruit; de `grep` verwijdert rtk's `ok`-sentinel, de `Changes:`-trailer en lege regels (geen bestanden).
   - Nieuwe (untracked) bestanden: `rtk git status --porcelain --untracked-files=all 2>/dev/null | grep -vx 'ok' | grep '^??' | sed 's/^?? //' | grep -v '^\.claude/plan-contracts/'` — `--untracked-files=all` somt untracked bestanden per stuk op (anders collapst een nieuwe map tot één regel en glipt het contract erdoor).

   Leg de vereniging van beide naast de Wijzigingen-tabel; meld per regel: geraakt-en-verwacht (ok), geraakt-maar-niet-in-tabel (afwijking), in-tabel-maar-niet-geraakt (ontbreekt).
2. **Bewijs-toets.** Draai per DoD-criterium de bewijsregel zélf en noteer de observatie. Een geskipte testmarker of gemockt pad telt níet als bewijs voor een criterium dat echt gedrag belooft (dezelfde regel als bij de DoD, SKILL.md stap 2a). Vereist het bewijs een key/omgeving die er niet is ("live, vereist `<KEY>`") → dat criterium is **niet toetsbaar** — niet "gehaald".
3. **Verdict per criterium** — dezelfde drieslag als de mission-verdicts: **gehaald** / **niet gehaald** / **niet toetsbaar** (met reden).
4. **Contract bijwerken** (het tweede schrijfmoment naar hetzelfde contractbestand): voeg onderaan een sectie "Toets-uitslag — `<datum>`" toe met de diff-afwijkingen en het verdict per criterium. Rapporteer hetzelfde in de chat.

**Niet-gehaald = rapporteren, nooit fixen.** Een toetser die repareert, toetst zijn eigen werk. De check-modus wijzigt alleen het contractbestand, nooit code.
