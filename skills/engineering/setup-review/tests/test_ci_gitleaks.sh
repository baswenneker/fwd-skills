#!/usr/bin/env bash
# The CI gitleaks step, run as the workflow runs it: download the pinned release,
# check its checksum, scan base..head. A commit with a fake AWS key fails the scan,
# even when it was made with --no-verify.
source "$(dirname "$0")/lib.sh"
if [[ -n "${FWD_TEST_OFFLINE:-}" ]] || ! command -v curl >/dev/null 2>&1 || [[ "$(uname -sm)" != "Linux x86_64" ]]; then
    echo "SKIP: CI gitleaks step (needs curl, Linux x86_64 and the network)"
    exit 0
fi

repo="$(make_repo ci)"
cd "$repo"
bash "$SCRIPTS/workflow/install.sh" --scope project >/dev/null
git add -A && git commit -q -m "add workflow"
base="$(git rev-parse HEAD)"

# Run the scan step exactly as the workflow writes it.
scan() {
    local cmd
    cmd="$(sed -n 's/^ *run: \(gitleaks git .*\)$/\1/p' .github/workflows/fwd-review.yml)"
    [[ -n "$cmd" ]] || { fail "scan command found in workflow"; return 0; }
    BASE_SHA="$base" HEAD_SHA="$(git rev-parse HEAD)" PATH="$bin:$PATH" eval "$cmd --no-banner" >/dev/null 2>&1
}

version="$(sed -n 's/^ *GITLEAKS_VERSION: *//p' .github/workflows/fwd-review.yml)"
sum="$(sed -n 's/^ *GITLEAKS_SHA256: *//p' .github/workflows/fwd-review.yml)"
[[ -n "$version" && -n "$sum" ]] || fail "workflow pins version and checksum"

bin="$WORK/bin"
mkdir -p "$bin"
(
    cd "$bin"
    curl -sSfL -o gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_x64.tar.gz"
    echo "${sum}  gitleaks.tar.gz" | sha256sum -c - >/dev/null
    tar -xzf gitleaks.tar.gz gitleaks
) || fail "pinned gitleaks downloads and matches its checksum"

echo "clean change" >> README.md
git commit -q -am "clean"
scan || fail "clean range passes"

# A key that only exists in a merge commit (added while resolving the merge).
git checkout -q -b side "$base"
echo "side change" > side.txt
git add side.txt && git commit -q -m side
git checkout -q main
git merge -q --no-ff --no-commit side >/dev/null 2>&1
printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" > merged.ini
git add merged.ini && git commit -q --no-verify -m "merge side"
scan && fail "range with a key only in a merge commit fails"
git reset -q --hard HEAD~1

printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" > creds.ini
git add creds.ini && git commit -q --no-verify -m "add creds"
scan && fail "range with a fake AWS key fails"

finish
