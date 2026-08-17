#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
canonical_skill="${script_dir}/../agent-skills/okf-knowledge-ops"
packaged_skill="${script_dir}/okf-local/skills/okf-knowledge-ops"

diff -ru -- "${canonical_skill}" "${packaged_skill}"
claude plugin validate --strict "${script_dir}/okf-local"
