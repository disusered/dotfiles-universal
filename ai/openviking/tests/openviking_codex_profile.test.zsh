#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h:h:h}
source "$repo_root/ai/openviking/openviking-codex.zsh"
unset OPENVIKING_CLI_CONFIG_FILE

assert_eq() {
  local expected=$1
  local actual=$2
  local label=$3

  if [[ "$actual" != "$expected" ]]; then
    print -ru2 "not ok: $label"
    print -ru2 "expected: $expected"
    print -ru2 "actual:   $actual"
    exit 1
  fi
}

default_conf="$HOME/.openviking/ovcli.conf"
xbol_conf="$HOME/.openviking/ovcli-xbol.conf"

assert_eq "$xbol_conf" "$(_openviking_codex_cli_config /home/carlos/Development/XBOL)" "XBOL root uses XBOL OpenViking profile"
assert_eq "$xbol_conf" "$(_openviking_codex_cli_config /home/carlos/Development/XBOL/xbol-api-admin)" "XBOL child uses XBOL OpenViking profile"
assert_eq "$default_conf" "$(_openviking_codex_cli_config /home/carlos/.dotfiles)" "non-XBOL path uses default OpenViking profile"

print "ok"
