#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

required=(
  ".github/downstream-config-manifest.yml"
  ".github/workflows/deploy-pages.yml"
  ".github/workflows/upstream-sync.yml"
  "AI-Integration.md"
  "Operations.md"
  "Package.swift"
  "scripts/run-tests.sh"
)
for path in "${required[@]}"; do
  [[ -f "${ROOT}/${path}" ]] || {
    printf 'FAIL missing required downstream path: %s\n' "$path" >&2
    exit 1
  }
done

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
package = (root / "Package.swift").read_text()
transport = (root / "Sources/HermesDesktop/Services/SSH/SSHTransport.swift").read_text()
workflow = (root / ".github/workflows/upstream-sync.yml").read_text()
assert ".macOS(.v14)" in package, "macOS 14 package contract disappeared"
assert "/usr/bin/ssh" in transport, "SSH transport contract disappeared"
assert workflow.count("for attempt in 1 2 3; do") == 3, "upstream fetches must retry three times"
assert workflow.count('git fetch --no-tags "https://github.com/${UPSTREAM_REPOSITORY}.git"') == 3, (
    "every upstream fetch must use bounded retries"
)
reuse = 'existing_prs=$(gh api --paginate'
identity = 'commit_identity=$(gh api'
push = 'git push --set-upstream origin "HEAD:refs/heads/$branch"'
create = 'url=$(gh pr create --head "$branch" --base "$DOWNSTREAM_BRANCH"'
published = 'published_head=$(git rev-parse HEAD)'
verify_created = 'if [[ "$pr_base" != "$BASE_SHA" || "$pr_head" != "$published_head" ]]'
cleanup = 'trap cleanup_created_pr ERR'
disarm = 'trap - ERR'
assert reuse in workflow and identity in workflow, "PR reuse must verify exact candidate provenance"
assert published in workflow and verify_created in workflow, "new PRs must retain the exact validated head"
assert workflow.index(create) < workflow.index(cleanup) < workflow.rindex(disarm), (
    "created PR verification must retain cleanup until the full identity is confirmed"
)
assert workflow.count('test "$(git show -s --format=%P HEAD)" = "$EXPECTED_PARENTS"') == 2, (
    "validation and finalization must verify exact candidate parents"
)
assert workflow.index(reuse) < workflow.index(published) < workflow.index(push) < workflow.index(create), (
    "an existing exact-candidate PR must be reused before creating another"
)
PY

if command -v actionlint >/dev/null 2>&1; then
  actionlint "${ROOT}/.github/workflows/"*.yml
fi

python3 "${ROOT}/scripts/test-upstream-sync-workflow.py"
"${ROOT}/scripts/run-tests.sh"
printf 'PASS Hermes Desktop downstream contract and Swift tests\n'
