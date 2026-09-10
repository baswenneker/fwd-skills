#!/usr/bin/env bash
# Validate a mission's artifacts, then commit the plan on the mission branch.
# Run by fwd:mission-plan after Claude has written mission.md / validation-contract.md /
# state.json into the worktree. Non-zero exit = fix what's reported and re-run.
# Args: <slug>
set -euo pipefail

SLUG="${1:?usage: validate-artifacts.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
MDIR="$WT_PATH/.claude/missions/$SLUG"
STATE="$MDIR/state.json"

[[ -d "$WT_PATH" ]] || { echo "worktree missing: $WT_PATH — run init-mission.sh first" >&2; exit 1; }

errs=()
for f in mission.md validation-contract.md state.json; do
  [[ -f "$MDIR/$f" ]] || errs+=("missing $f")
done

if [[ -f "$STATE" ]]; then
  if ! jq -e . "$STATE" >/dev/null 2>&1; then
    errs+=("state.json is not valid JSON")
  else
    jq -e '.status and (.slug|type=="string") and (.features|type=="array") and (.milestones|type=="array") and (.gates|type=="array")' "$STATE" >/dev/null 2>&1 \
      || errs+=("state.json missing required fields (status/slug/features/milestones/gates)")
    [[ "$(jq '.features  | length' "$STATE" 2>/dev/null || echo 0)" -ge 1 ]] || errs+=("state.json has no features")
    [[ "$(jq '.milestones | length' "$STATE" 2>/dev/null || echo 0)" -ge 1 ]] || errs+=("state.json has no milestones")
    jq -e 'all(.features[];   .id and .status and (.vc_ids|type=="array"))' "$STATE" >/dev/null 2>&1 || errs+=("a feature is missing id/status/vc_ids")
    jq -e 'all(.milestones[]; .id and (.feature_ids|type=="array"))'        "$STATE" >/dev/null 2>&1 || errs+=("a milestone is missing id/feature_ids")
  fi
fi

if [[ -f "$MDIR/mission.md" ]]; then
  grep -Eq '^## Zo ziet klaar eruit' "$MDIR/mission.md" \
    || errs+=("mission.md mist de sectie '## Zo ziet klaar eruit' (het verplichte eindbeeld)")
fi

if [[ -f "$MDIR/validation-contract.md" ]]; then
  grep -Eq 'VC-[0-9]+' "$MDIR/validation-contract.md" || errs+=("validation-contract.md has no VC- assertions")

  # Robustness coverage: every feature needs a line in '## Robuustheid' that either
  # names covering VC's or records an explicit user-confirmed waiver.
  if ! grep -Eq '^## Robuustheid' "$MDIR/validation-contract.md"; then
    errs+=("validation-contract.md mist de sectie '## Robuustheid'")
  elif [[ -f "$STATE" ]] && jq -e . "$STATE" >/dev/null 2>&1; then
    ROBUST_SECTION="$(awk '/^## Robuustheid/{flag=1;next}/^## /{flag=0}flag' "$MDIR/validation-contract.md")"
    while IFS= read -r fid; do
      [[ -n "$fid" ]] || continue
      # Escape regex metacharacters: feature ids are F<n> by convention, but an exotic
      # id must fail closed instead of matching (or breaking) the pattern.
      fid_re="$(sed -e 's/[][\.|$(){}?+*^\\]/\\&/g' <<<"$fid")"
      grep -E "(^|[^A-Za-z0-9])${fid_re}([^0-9]|$)" <<<"$ROBUST_SECTION" | grep -Eq 'VC-[0-9]+|waiver' \
        || errs+=("Robuustheid: feature ${fid} heeft geen VC-verwijzing of waiver")
    done < <(jq -r '.features[].id // empty' "$STATE" 2>/dev/null)
  fi
fi

# ── Plan-lint: contract ↔ state consistency ──────────────────────────────────
# Anchors on the bold assertion pattern (**VC-n**) so prose mentions of a VC
# (summaries, the Robuustheid section) never count as assertions. Runs only
# when both the contract and a valid state.json are present. Plan-phase only:
# stricter than what the runner tolerates at execution time.
if [[ -f "$MDIR/validation-contract.md" && -f "$STATE" ]] && jq -e . "$STATE" >/dev/null 2>&1; then
  CONTRACT_VCS="$(grep -oE '\*\*VC-[0-9]+\*\*' "$MDIR/validation-contract.md" 2>/dev/null | tr -d '*' | sort -u || true)"
  STATE_VCS="$(jq -r '.features[]?.vc_ids[]? // empty' "$STATE" 2>/dev/null | sort -u || true)"

  # A contract that mentions VC's but has zero bold assertions deviated from the
  # template format — say so once, instead of one cryptic error per vc_id.
  if [[ -z "$CONTRACT_VCS" ]] && grep -Eq 'VC-[0-9]+' "$MDIR/validation-contract.md"; then
    errs+=("plan-lint: geen enkele **VC-n**-assertion gevonden terwijl het contract wel VC's noemt — schrijf assertions als '- **VC-n** (owner): ...' conform het template")
  fi

  # Every vc_id a feature targets must exist as a real assertion in the contract.
  while IFS= read -r vc; do
    [[ -n "$vc" ]] || continue
    grep -qx -- "$vc" <<<"$CONTRACT_VCS" \
      || errs+=("plan-lint: state.json verwijst naar $vc maar het contract heeft geen **$vc**-assertion")
  done <<<"$STATE_VCS"

  # Every contract assertion must be targeted by at least one feature.
  while IFS= read -r vc; do
    [[ -n "$vc" ]] || continue
    grep -qx -- "$vc" <<<"$STATE_VCS" \
      || errs+=("plan-lint: contract-assertion $vc is aan geen enkele feature gekoppeld (vc_ids)")
  done <<<"$CONTRACT_VCS"

  # Milestone ↔ feature integrity: referenced features exist, every feature
  # points at an existing milestone, and that milestone lists the feature back.
  MF_ERRS="$(jq -r '
    [.features[]?.id] as $fids
    | [.milestones[]?.id] as $mids
    | ( [ .milestones[]? as $m
          | ($m.feature_ids // [])[]
          | select((. as $f | $fids | index($f)) | not)
          | "plan-lint: milestone \($m.id) noemt onbekende feature \(.)" ]
      + [ .features[]?
          | select((.milestone == null) or ((.milestone as $mm | $mids | index($mm)) | not))
          | "plan-lint: feature \(.id) wijst naar geen bestaande milestone (milestone: \(.milestone // "ontbreekt"))" ]
      + [ . as $root | .features[]?
          | select(.milestone != null) | . as $f
          | ($root.milestones[]? | select(.id == $f.milestone)) as $m
          | select(((($m.feature_ids // []) | index($f.id))) | not)
          | "plan-lint: feature \($f.id) staat niet in feature_ids van zijn milestone \($f.milestone)" ]
      )[]
  ' "$STATE" 2>/dev/null || true)"
  while IFS= read -r e; do
    [[ -n "$e" ]] || continue
    errs+=("$e")
  done <<<"$MF_ERRS"

  # A user-testing assertion is only judgeable when the app can actually boot.
  # Anchor on the assertion shape ("**VC-n** (user-testing)"): the template's
  # "## App boot (user-testing)" heading and prose must never trigger this.
  if grep -qE '\*\*VC-[0-9]+\*\*[[:space:]]*\(user-testing\)' "$MDIR/validation-contract.md"; then
    jq -e '.user_testing.boot_command | type=="string" and length>0' "$STATE" >/dev/null 2>&1 \
      || errs+=("plan-lint: user-testing-VC's in het contract maar geen boot_command in state.json — die VC's worden nooit beoordeeld")
  fi
fi
# ── end plan-lint ─────────────────────────────────────────────────────────────

# ── Rules-manifest check (schema v3, additive) ───────────────────────────────
# Only runs when state.json is present, valid JSON, AND .rules_manifest is a
# non-empty array. Plans without the field (v1/v2) pass through unchanged.
if [[ -f "$STATE" ]] && jq -e '.' "$STATE" >/dev/null 2>&1 \
   && jq -e '(.rules_manifest | type) == "array" and (.rules_manifest | length) > 0' \
      "$STATE" >/dev/null 2>&1; then

  # Resolve repo root: scripts may be called from anywhere, so use the worktree.
  MANIFEST_REPO_ROOT="$(rtk git -C "$WT_PATH" rev-parse --show-toplevel 2>/dev/null \
    || rtk git -C "$WT_PATH" rev-parse --git-common-dir 2>/dev/null | xargs dirname \
    || echo "$WT_PATH")"

  # Choose hashing tool: shasum (macOS) with sha256sum as fallback.
  if command -v shasum >/dev/null 2>&1; then
    _sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
  elif command -v sha256sum >/dev/null 2>&1; then
    _sha256() { sha256sum "$1" | awk '{print $1}'; }
  else
    errs+=("rules_manifest: no sha256 tool found (need shasum or sha256sum)")
    _sha256() { echo ""; }
  fi

  manifest_len="$(jq '.rules_manifest | length' "$STATE")"
  for ((i=0; i<manifest_len; i++)); do
    entry_path="$(jq -r ".rules_manifest[$i].path" "$STATE")"
    entry_sha="$(jq  -r ".rules_manifest[$i].sha256" "$STATE")"
    full_path="$MANIFEST_REPO_ROOT/$entry_path"

    if [[ ! -f "$full_path" ]]; then
      errs+=("rules_manifest: file missing: $entry_path")
    else
      actual_sha="$(_sha256 "$full_path")"
      if [[ "$actual_sha" != "$entry_sha" ]]; then
        errs+=("rules_manifest: hash mismatch for $entry_path (expected $entry_sha, got $actual_sha)")
      fi
    fi
  done
fi
# ── end rules-manifest check ─────────────────────────────────────────────────

# ── depends_on lint (schema v6, additive) ────────────────────────────────────
# Tolerant for plans without the field: only runs when at least one feature
# actually carries depends_on. Enforces three things so pick-next-unit.sh can
# trust the graph without doing its own validation: every referenced id exists,
# every reference points backward (to a feature earlier in the array — no
# forward references), and there are no cycles.
if [[ -f "$STATE" ]] && jq -e '.' "$STATE" >/dev/null 2>&1 \
   && jq -e '[.features[]?.depends_on? // [] | .[]] | length > 0' "$STATE" >/dev/null 2>&1; then

  DEP_ERRS="$(jq -r '
    [.features[]?.id] as $ids
    | (.features | to_entries | map({key: .value.id, value: .key}) | from_entries) as $index
    | (.features | map({key: .id, value: (.depends_on // [])}) | from_entries) as $deps

    | def cycle_from(fid; visited):
        (($deps[fid] // [])[]) as $d
        | if (visited | index($d)) then $d
          else cycle_from($d; visited + [$d])
          end;

    ( [ .features[]? | . as $f | ($f.depends_on // [])[]
        | select((. as $d | $ids | index($d)) | not)
        | "plan-lint: feature \($f.id) heeft depends_on naar onbekende feature \(.)" ]
      + [ .features[]? | . as $f | ($f.depends_on // [])[]
          | select((. as $d | $ids | index($d)) != null)
          | select($index[.] >= $index[$f.id])
          | "plan-lint: feature \($f.id) heeft depends_on naar \(.), maar dat is geen eerdere feature (vooruit-verwijzing)" ]
      + ( [ .features[]?.id ] | unique | map(
            . as $start
            | (try cycle_from($start; [$start]) catch null)
          ) | map(select(. != null)) | if length > 0 then ["plan-lint: cykel in depends_on gedetecteerd (via feature \(.[0]))"] else [] end )
    )[]
  ' "$STATE" 2>/dev/null || true)"
  while IFS= read -r e; do
    [[ -n "$e" ]] || continue
    errs+=("$e")
  done <<<"$DEP_ERRS"
fi
# ── end depends_on lint ───────────────────────────────────────────────────────

if [[ ${#errs[@]} -gt 0 ]]; then
  echo "invalid mission artifacts for $SLUG:" >&2
  for e in "${errs[@]}"; do echo "  - $e" >&2; done
  exit 1
fi

# Commit the plan on the mission branch. Stage ONLY the mission dir — never the
# copied .env or anything else that might be sitting in the worktree.
cd "$WT_PATH"
rtk git add -- ".claude/missions/$SLUG" >&2
if rtk git diff --cached --quiet; then
  echo "ok — artifacts valid (nothing new to commit)"
  exit 0
fi
rtk git commit -q -m "docs(mission): scope $SLUG" >&2
echo "ok — committed plan for $SLUG on mission/$SLUG ($(rtk git rev-parse --short HEAD))"
