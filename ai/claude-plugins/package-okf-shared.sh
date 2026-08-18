#!/usr/bin/env bash
# Package the shared-corpus skill for upload to the Iteramind organization, alongside the
# hosted OKF connector.
#
# Deliberately carries no mcpServers entry and no local paths: the connector supplies the
# tools, this supplies the method, and a teammate has no checkout of anything.
#
# The organization copy is a snapshot. Re-run this and re-upload after editing the canonical
# skill at ai/agent-skills/okf-shared-corpus, or the team's copy drifts from ours.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
canonical_skill="${script_dir}/../agent-skills/okf-shared-corpus"
artifact_dir="${script_dir}/dist"
artifact="${artifact_dir}/okf-shared-corpus.zip"
stage="$(mktemp -d)"
trap 'rm -rf -- "${stage}"' EXIT

mkdir -p -- "${artifact_dir}" "${stage}/.claude-plugin" "${stage}/skills"
cp -RL -- "${canonical_skill}" "${stage}/skills/okf-shared-corpus"

# Nothing Carlos-specific may ship here: the audience is the whole organization.
if grep -rqE '/home/carlos|knowledge/private|polychrome|XBOL' "${stage}/skills"; then
  echo "refusing to package: the skill references local paths or another brain" >&2
  grep -rnE '/home/carlos|knowledge/private|polychrome|XBOL' "${stage}/skills" >&2
  exit 1
fi

cat > "${stage}/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "okf-shared-corpus",
  "displayName": "Iteramind Shared Knowledge",
  "version": "0.1.0",
  "description": "How to read and curate the Iteramind shared knowledge corpus through the hosted OKF connector.",
  "author": {
    "name": "Iteramind"
  },
  "keywords": ["knowledge", "okf", "shared", "skill"]
}
JSON

cat > "${stage}/README.md" <<'MD'
# Iteramind Shared Knowledge

The method for using the hosted OKF connector: authority order, what makes a page valid, how a
change is checked and saved, and what a refused save means.

Pair it with the OKF connector. The connector provides the `okf_*` tools; without this skill a
reader gets the tools and none of the rules.

It declares no MCP server and names no local path. The shared corpus is objects in R2 reached
only through the connector, so there is nothing on disk to point at.

Rebuild with `package-okf-shared.sh` after editing the canonical skill at
`ai/agent-skills/okf-shared-corpus`, then re-upload. The organization copy is a snapshot and
does not track the source.
MD

rm -f -- "${artifact}"
(
  cd -- "${stage}"
  zip -q -r "${artifact}" .
)

printf '%s\n' "${artifact}"
