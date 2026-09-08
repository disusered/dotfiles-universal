#!/usr/bin/env python3
"""Offline policy characterization and harmless shell failure-handling fixtures.

Runs only `codex execpolicy check` and local shell fixtures, never the commands
being classified. An allow rule is execution permission, not task authorization.
Unmatched means no rule in this file matched; it is not a runtime denial.
This does not test credentials, network/sandbox access, or agent behavior.
"""

import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


REPO = Path(__file__).resolve().parents[3]
RULES = REPO / "ai/codex/rules/default.rules"

# argv forms are intentional: execpolicy does not simulate the tool's shell
# decomposition. These characterize the repository source, not session grants.
CASES = [
    ("allow", "gh pr view 123 --json title"),
    ("allow", "gh api repos/example/project"),
    ("allow", "op run --env-file /tmp/policy-placeholder.env -- npm test"),
    ("allow", "op item get policy-placeholder --fields title"),
    ("unmatched", "op read op://policy-placeholder/item/field"),
    ("allow", "git status --short"),
    ("allow", "git commit -S -m policy-placeholder"),
    ("allow", "git verify-commit HEAD"),
    ("unmatched", "git -C /tmp status --short"),
    ("allow", "jj status"),
    ("allow", "jj diff"),
    ("unmatched", "jj commit -m policy-placeholder"),
    ("allow", "aws sts get-caller-identity"),
    ("allow", "gcloud auth list"),
    ("allow", "cloud-sql-proxy --version"),
    ("allow", "psql --version"),
    ("allow", "docker ps"),
    ("allow", "docker compose config"),
    ("unmatched", "docker compose -f /tmp/policy-placeholder.yml ps"),
    ("allow", "podman ps"),
    ("allow", "podman compose ps"),
    ("unmatched", "podman compose logs"),
    ("allow", "cfg run policy-placeholder"),
    ("allow", "cfg up --workspace"),
    ("unmatched", "cfg down --workspace"),
    ("allow", "npm test"),
    ("allow", "pnpm test"),
    ("allow", "npx playwright test"),
    ("prompt", "zsh -lc 'gh pr list'"),
    ("prompt", "bash local-script.sh"),
    ("unmatched", "env AUDIT_PLACEHOLDER=1 gh pr list"),
    ("forbidden", "tofu plan"),
    ("forbidden", "terraform init"),
    ("forbidden", "git commit --no-gpg-sign -m policy-placeholder"),
    ("forbidden", "git -c commit.gpgsign=false commit -m policy-placeholder"),
]

for account, site, keys in [
    ("iteramind", "iteramind", ("LEX-1", "LEX-2")),
    ("odasoft", "odasoftmx", ("XBS-1", "XBS-2")),
]:
    prefix = f"env TWG_CONFIG_DIR=/home/carlos/.config/twg/accounts/{account} twg"
    for key in keys:
        CASES.append(("allow", f"{prefix} jira workitem get {key} --site {site}"))
    for query in ("status = Open", "status = Closed"):
        CASES.append(("allow", f"{prefix} jira workitem query --jql '{query}' --site {site}"))
    CASES.extend([
        ("allow", f"{prefix} jira board query --site {site}"),
        ("unmatched", f"{prefix} --site {site} jira workitem get {keys[0]}"),
        ("unmatched", f"{prefix} jira workitem create --site {site}"),
    ])


def run(argv, **kwargs):
    return subprocess.run(argv, capture_output=True, text=True, timeout=30, **kwargs)


def check_policy():
    counts = dict.fromkeys(("allow", "prompt", "forbidden", "unmatched"), 0)
    for expected, command in CASES:
        result = run(["codex", "execpolicy", "check", "--rules", str(RULES),
                      "--", *shlex.split(command)])
        if result.returncode:
            raise RuntimeError(f"Policy checker failed: {result.stderr}")
        payload = json.loads(result.stdout)
        actual = payload.get("decision", "unmatched")
        if actual == "unmatched" and payload.get("matchedRules"):
            raise AssertionError(f"Unexpected checker output: {payload}")
        if actual != expected:
            raise AssertionError(f"{command}: expected {expected}, got {actual}")
        counts[actual] += 1
        print(f"PASS {actual:9} {command}")
    print(f"Policy: {len(CASES)} cases passed against {RULES}; {counts}")


def check_environment():
    marker = "EXECUTION_CHECK_FIXTURE"
    clean_env = os.environ.copy()
    clean_env.pop(marker, None)
    with tempfile.TemporaryDirectory(prefix="execution-check-") as directory:
        fixture = Path(directory) / "fixture.env"
        fixture.write_text(f"{marker}=loaded\n")
        # Load and consume in one invocation, including inheritance by a child.
        loaded = run(["sh", "-c", 'set -a; . "$1"; set +a; '
                      'sh -c \'test "$EXECUTION_CHECK_FIXTURE" = loaded\'',
                      "fixture", str(fixture)], env=clean_env)
        if loaded.returncode:
            raise AssertionError("Same-process environment loading failed")
        separate = run(["sh", "-c", 'test -z "${EXECUTION_CHECK_FIXTURE+x}"'],
                       env=clean_env)
        if separate.returncode:
            raise AssertionError("Separate invocation unexpectedly inherited fixture")
    print("PASS environment: same-process loader reaches child; later shell is independent")


def check_pipeline():
    # A producer can emit plausible output and then fail. A successful consumer
    # alone does not establish success of the operation that produced the data.
    pipeline = "(printf '%s' fixture; exit 23) | cat"
    unchecked = run(["bash", "-c", pipeline])
    checked = run(["bash", "-o", "pipefail", "-c", pipeline])
    producer = run(["sh", "-c", "printf '%s' fixture; exit 23"])
    if (unchecked.returncode, checked.returncode, producer.returncode) != (0, 23, 23):
        raise AssertionError("Unexpected upstream failure fixture statuses")
    if not all(result.stdout == "fixture" for result in (unchecked, checked, producer)):
        raise AssertionError("Unexpected upstream failure fixture output")
    print("PASS pipeline: default status masks failure; pipefail and separate capture preserve 23")


if __name__ == "__main__":
    check_policy()
    check_environment()
    check_pipeline()
    print("Offline checks passed. Live access and model behavior were not exercised.")
