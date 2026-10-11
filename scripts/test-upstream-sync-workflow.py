#!/usr/bin/env python3
"""Focused behavioral tests for the upstream synchronization workflow."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/upstream-sync.yml"


def workflow_script(step_name: str) -> str:
    lines = WORKFLOW.read_text().splitlines()
    start = next(index for index, line in enumerate(lines) if line.strip() == f"- name: {step_name}")
    run = next(index for index in range(start + 1, len(lines)) if lines[index].strip() == "run: |")
    run_indent = len(lines[run]) - len(lines[run].lstrip())
    body: list[str] = []
    for line in lines[run + 1 :]:
        indent = len(line) - len(line.lstrip())
        if line.strip() and indent <= run_indent:
            break
        body.append(line[run_indent + 2 :] if line.strip() else "")
    return "\n".join(body) + "\n"


def run_script(script: str, commands: dict[str, str], environment: dict[str, str]) -> tuple[str, str]:
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        bin_dir = temp / "bin"
        bin_dir.mkdir()
        for name, body in commands.items():
            executable = bin_dir / name
            executable.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
            executable.chmod(0o755)
        env = os.environ.copy()
        env.update(environment)
        env["PATH"] = f"{bin_dir}:{env['PATH']}"
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=temp,
            env=env,
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"workflow fixture failed with {result.returncode}:\n{result.stdout}{result.stderr}"
        )
        output_path = Path(environment["GITHUB_OUTPUT"]) if "GITHUB_OUTPUT" in environment else None
        summary_path = Path(environment["GITHUB_STEP_SUMMARY"]) if "GITHUB_STEP_SUMMARY" in environment else None
        output = output_path.read_text() if output_path and output_path.exists() else ""
        summary = summary_path.read_text() if summary_path and summary_path.exists() else ""
        return output, summary


prepare = workflow_script("Resolve and reconstruct the downstream candidate")
finalize = workflow_script("Publish exact validated tree without executing it")

with tempfile.TemporaryDirectory() as paths:
    output_path = str(Path(paths) / "output")
    retry_state = str(Path(paths) / "retry-count")
    output, _ = run_script(
        prepare,
        {
            "git": f'''\nif [[ "$1 $2" == "rev-parse HEAD" ]]; then printf '%040d\\n' 1; exit 0; fi
if [[ "$1 $2" == "rev-parse FETCH_HEAD" ]]; then printf '%040d\\n' 2; exit 0; fi
if [[ "$1" == "fetch" ]]; then
  count=0; [[ -f "{retry_state}" ]] && count=$(cat "{retry_state}")
  count=$((count + 1)); printf '%s' "$count" > "{retry_state}"
  [[ "$count" -ge 3 ]]
  exit
fi
if [[ "$1 $2" == "merge-base --is-ancestor" ]]; then exit 0; fi
printf 'unexpected git command: %s\\n' "$*" >&2; exit 99
''',
            "sleep": ":",
        },
        {"GITHUB_OUTPUT": output_path, "UPSTREAM_REPOSITORY": "example/upstream"},
    )
    assert Path(retry_state).read_text() == "3", "prepare did not retry the transient fetch twice"
    assert "changed=false" in output, "prepare did not complete after the third fetch attempt"

base = "a" * 40
upstream = "b" * 40
tree = "c" * 40
remote_head = "d" * 40
parents = f"{base} {upstream}"


def run_finalize_fixture(existing_parents: str) -> tuple[str, str]:
    with tempfile.TemporaryDirectory() as paths:
        paths = Path(paths)
        summary_path = str(paths / "summary")
        trace_path = str(paths / "trace")
        _, summary = run_script(
            finalize,
            {
                "git": f'''\nprintf 'git %s\\n' "$*" >> "{trace_path}"
if [[ "$1 $2 ${{3-}}" == "ls-remote origin refs/heads/main" ]]; then printf '%s\\trefs/heads/main\\n' "{base}"; exit 0; fi
if [[ "$1" == "fetch" || "$1" == "config" || "$1" == "merge" || "$1" == "restore" || "$1" == "commit" ]]; then exit 0; fi
if [[ "$1 $2" == "rev-parse HEAD^{{tree}}" ]]; then printf '%s\\n' "{tree}"; exit 0; fi
if [[ "$1 $2 ${{3-}}" == "show -s --format=%P" ]]; then printf '%s\\n' "{parents}"; exit 0; fi
if [[ "$1" == "push" ]]; then exit 0; fi
printf 'unexpected git command: %s\\n' "$*" >&2; exit 99
''',
                "gh": f'''\nprintf 'gh %s\\n' "$*" >> "{trace_path}"
if [[ "$1 $2" == "api --paginate" ]]; then
  printf 'https://example.invalid/pr/1\\t%s\\texample/downstream\\t%s\\n' "{base}" "{remote_head}"
  exit 0
fi
if [[ "$1" == "api" ]]; then printf '%s\\t%s\\n' "{tree}" "{existing_parents}"; exit 0; fi
if [[ "$1 $2" == "pr create" ]]; then printf '%s\\n' 'https://example.invalid/pr/2'; exit 0; fi
if [[ "$1 $2" == "pr view" ]]; then printf '%s\\n' "{base}"; exit 0; fi
printf 'unexpected gh command: %s\\n' "$*" >&2; exit 99
''',
                "sleep": ":",
            },
            {
                "BASE_SHA": base,
                "DOWNSTREAM_BRANCH": "main",
                "EXPECTED_TREE": tree,
                "EXPECTED_PARENTS": parents,
                "GH_TOKEN": "fixture-token",
                "GITHUB_REPOSITORY": "example/downstream",
                "GITHUB_RUN_ATTEMPT": "1",
                "GITHUB_RUN_ID": "123",
                "GITHUB_STEP_SUMMARY": summary_path,
                "UPSTREAM_REPOSITORY": "example/upstream",
                "UPSTREAM_SHA": upstream,
            },
        )
        return Path(trace_path).read_text(), summary


trace, summary = run_finalize_fixture(parents)
assert "git push" not in trace, "a repeated candidate must not push another branch"
assert "gh pr create" not in trace, "a repeated candidate must not create a duplicate PR"
assert "Existing synchronization PR: https://example.invalid/pr/1" in summary

trace, _ = run_finalize_fixture("e" * 40)
assert "git push" in trace, "a different commit topology must publish the validated candidate"
assert "gh pr create" in trace, "a different commit topology must not be reused"

print("PASS upstream sync retries transient fetches and reuses the exact candidate PR")
