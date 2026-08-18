#!/usr/bin/env bash
# Package the OKF knowledge skill on its own, for surfaces that consume skills but not
# local MCP servers — Claude Desktop's Plugins panel, and through it Web and Cowork.
#
# Deliberately carries no mcpServers entry. The shared corpus is reached through the hosted
# server registered as a connector, and the private corpus is reached by opening files in a
# folder shared with Cowork. Neither needs a server launched from a plugin.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
canonical_skill="${script_dir}/../agent-skills/okf-knowledge-ops"
artifact_dir="${script_dir}/dist"
artifact="${artifact_dir}/okf-knowledge.zip"
stage="$(mktemp -d)"
trap 'rm -rf -- "${stage}"' EXIT

mkdir -p -- "${artifact_dir}" "${stage}/.claude-plugin" "${stage}/skills"
cp -RL -- "${canonical_skill}" "${stage}/skills/okf-knowledge-ops"

cat > "${stage}/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "okf-knowledge",
  "displayName": "OKF Knowledge",
  "version": "0.1.0",
  "description": "Operating instructions for governed OKF Markdown bundles, for surfaces that read files directly or call a hosted OKF server.",
  "author": {
    "name": "Carlos Rosquillas"
  },
  "keywords": ["knowledge", "okf", "skill"]
}
JSON

cat > "${stage}/README.md" <<'MD'
# OKF Knowledge

The `okf-knowledge-ops` skill on its own, with no MCP server.

Use it where a surface reads files directly or calls a hosted OKF server:

- **Claude Desktop and Cowork**, for the Iteramind private corpus, once the repository
  folder is shared in the Desktop UI. The skill supplies the method; `validate_okf.py` in
  the repository supplies the checking.
- **Any surface with the hosted shared server connected**, for the Iteramind shared corpus.

It intentionally declares no `mcpServers`. A server exists to reach files a surface cannot
open for itself; a plugin should not start one for files that are already open.

Rebuild with `package-okf-skill.sh` after editing the canonical skill at
`ai/agent-skills/okf-knowledge-ops`, then re-upload. Desktop holds a snapshot and does not
track the dotfiles copy.
MD

rm -f -- "${artifact}"
(
  cd -- "${stage}"
  zip -q -r "${artifact}" .
)

printf '%s\n' "${artifact}"
