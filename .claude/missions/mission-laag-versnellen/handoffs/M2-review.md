# Milestone-review M2 — Run-machinerie goedkoper

## In één oogopslag
M2 is solide en volledig — alle 9 criteria slagen, geen zorgen. F2 hardt `record-feature.sh` met veld-specifieke handoff-validatie en een clean-worktree-check die alleen untracked handoff-narratives uitzondert terwijl tracked wijzigingen elders blijven falen. F3 voegt een read-only Haiku scribe-agent toe (geen Write/Edit, compileert alleen, oordeelt nooit) plus een gate-bewuste reviewer-prompt. De comment-hygiëne is schoon en de diff blijft binnen het design-budget. De reviewer draaide de veldvalidatie zelf (gericht, geen volledige suite): volledige handoff slaagt, ontbrekend veld wordt met naam geweigerd — het sad-path-bewijs is niet tautologisch.

## Verdicts (allemaal PASS)
- VC-7 — untracked handoff-narrative uitgezonderd; tracked vuiligheid blijft falen (record-feature.sh:62-66).
- VC-8 — vijf verplichte velden + rules_applied gevalideerd met veld-specifieke melding (record-feature.sh:43-56).
- VC-9 — scribe met model haiku, geen Write/Edit; SKILL.md delegeert compileren, orchestrator schrijft/commit.
- VC-10 — volledige verificatiepas + verplichte slotregel in de scribe.
- VC-11 — reviewer-prompt krijgt gate_results + HEAD-SHA met her-run-verbod op gelijke SHA (SKILL.md:123).
- VC-12 — geen oordeel gedelegeerd aan de scribe; expliciet vastgelegd.
- VC-13 — geen mission-code in productcode-comments of commit-message.
- VC-14 — fixtures roepen het échte script aan; sad-path discrimineert.
- VC-15 — alleen de toegestane scribe-agent; geen nieuwe dependency/map/abstractie.
