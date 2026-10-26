#!/usr/bin/env bash
# Package the skills our claude.ai plugins carry as one zip per skill for the Gemini web app's
# Skills page (gemini.google.com → Skills → Upload). Gemini takes one skill per upload and
# rejects a zip unless SKILL.md sits at its root, so each zip holds the skill's files directly.
#
# The skill set follows ai/claude-plugins, so Claude and Gemini get the same skills. The generic
# okf-knowledge-ops skill ships in the Iteramind organization's OKF Knowledge plugin rather than
# here, so it is packaged from that checkout.
#
# Gemini holds a snapshot and does not track the dotfiles copy. Rebuild after editing a skill,
# then re-upload the changed zip.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugins_dir="${script_dir}/../claude-plugins"
okf_skill="${HOME}/Development/ITERAMIND/projects/agent-plugins/plugins/okf-knowledge/skills/okf-knowledge-ops"
artifact_dir="${script_dir}/dist"
mkdir -p -- "${artifact_dir}"

package() {
  local source_dir="$1"
  local name artifact stage
  name="$(basename -- "${source_dir}")"
  artifact="${artifact_dir}/${name}.zip"
  stage="$(mktemp -d)"
  # Skill folders are links into ai/agent-skills; copy what they point to.
  cp -RL -- "${source_dir}/." "${stage}/"
  rm -f -- "${artifact}"
  (cd -- "${stage}" && zip -q -r "${artifact}" .)
  rm -rf -- "${stage}"
  printf '%s\n' "${artifact}"
}

for skill in "${plugins_dir}"/*/skills/*/; do
  package "${skill%/}"
done
package "${okf_skill}"
