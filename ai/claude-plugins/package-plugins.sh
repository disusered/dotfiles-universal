#!/usr/bin/env bash
# Package each plugin here as a zip for claude.ai's Upload plugin, which reaches Claude web,
# Desktop chat, Cowork and Claude Code from one upload.
#
# The plugins carry skills only. Their connectors are claude.ai account connectors, so a plugin
# that also declared mcpServers would list the same server twice. okf-knowledge-ops ships once,
# in okf-knowledge, which brain-portal and xbol-knowledge both rely on.
#
# claude.ai holds a snapshot and does not track the dotfiles copy. Rebuild after editing a
# skill under ai/agent-skills, then re-upload the changed zip.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifact_dir="${script_dir}/dist"
mkdir -p -- "${artifact_dir}"

for plugin in "${script_dir}"/*/.claude-plugin/plugin.json; do
  source_dir="$(dirname -- "$(dirname -- "${plugin}")")"
  name="$(basename -- "${source_dir}")"
  artifact="${artifact_dir}/${name}.zip"
  stage="$(mktemp -d)"
  # Skill folders are links into ai/agent-skills; copy what they point to.
  cp -RL -- "${source_dir}/." "${stage}/"
  rm -f -- "${artifact}"
  (cd -- "${stage}" && zip -q -r "${artifact}" .)
  rm -rf -- "${stage}"
  printf '%s\n' "${artifact}"
done
