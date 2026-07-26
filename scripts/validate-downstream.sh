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
readme = (root / "README.md").read_text()
assert ".macOS(.v14)" in package, "macOS 14 package contract disappeared"
assert "connects directly over SSH" in readme, "direct SSH contract disappeared"
assert "does not mirror files onto your Mac" in readme, "no-local-mirror contract disappeared"
PY

if command -v actionlint >/dev/null 2>&1; then
  actionlint "${ROOT}/.github/workflows/"*.yml
fi

"${ROOT}/scripts/run-tests.sh"
printf 'PASS Hermes Desktop downstream contract and Swift tests\n'
