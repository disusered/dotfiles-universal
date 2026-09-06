#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
canonical_skill="${script_dir}/../agent-skills/okf-knowledge-ops"
stage="$(mktemp -d)"
trap 'rm -rf -- "${stage}"' EXIT

bash "${script_dir}/package-okf-local.sh"
unzip -q "${script_dir}/dist/okf-local.zip" -d "${stage}"
diff -ru -- "${canonical_skill}" "${stage}/skills/okf-knowledge-ops"
claude plugin validate --strict "${stage}"
