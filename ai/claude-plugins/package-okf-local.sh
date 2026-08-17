#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_source="${script_dir}/okf-local"
canonical_skill="${script_dir}/../agent-skills/okf-knowledge-ops"
artifact_dir="${script_dir}/dist"
artifact="${artifact_dir}/okf-local.zip"
stage="$(mktemp -d)"
trap 'rm -rf -- "${stage}"' EXIT

mkdir -p -- "${artifact_dir}"
cp -RL -- "${plugin_source}/." "${stage}/"
rm -rf -- "${stage}/skills/okf-knowledge-ops"
cp -RL -- "${canonical_skill}" "${stage}/skills/okf-knowledge-ops"
rm -f -- "${artifact}"
(
  cd -- "${stage}"
  zip -q -r "${artifact}" .
)

printf '%s\n' "${artifact}"
