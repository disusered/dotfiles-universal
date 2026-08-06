#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h:h:h}
source "$repo_root/ai/openviking/openviking-codex.zsh"
source "$repo_root/ai/openviking/openviking-claude.zsh"
source "$repo_root/ai/opencode/opencode.zsh"
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
iteramind_conf="$HOME/.openviking/ovcli-iteramind.conf"

assert_eq "$xbol_conf" "$(_openviking_codex_cli_config /home/carlos/Development/XBOL)" "XBOL root uses XBOL OpenViking profile"
assert_eq "$xbol_conf" "$(_openviking_codex_cli_config /home/carlos/Development/XBOL/xbol-api-admin)" "XBOL child uses XBOL OpenViking profile"
assert_eq "$iteramind_conf" "$(_openviking_codex_cli_config /home/carlos/Development/ITERAMIND)" "Iteramind root uses Iteramind OpenViking profile"
assert_eq "$iteramind_conf" "$(_openviking_codex_cli_config /home/carlos/Development/ITERAMIND/projects/example)" "Iteramind child uses Iteramind OpenViking profile"
assert_eq "$default_conf" "$(_openviking_codex_cli_config /home/carlos/.dotfiles)" "non-XBOL path uses default OpenViking profile"
assert_eq "$xbol_conf" "$(_openviking_claude_cli_config /home/carlos/Development/XBOL)" "Claude XBOL root uses XBOL OpenViking profile"
assert_eq "$xbol_conf" "$(_openviking_claude_cli_config /home/carlos/Development/XBOL/xbol-api-admin)" "Claude XBOL child uses XBOL OpenViking profile"
assert_eq "$iteramind_conf" "$(_openviking_claude_cli_config /home/carlos/Development/ITERAMIND)" "Claude Iteramind root uses Iteramind OpenViking profile"
assert_eq "$iteramind_conf" "$(_openviking_claude_cli_config /home/carlos/Development/ITERAMIND/projects/example)" "Claude Iteramind child uses Iteramind OpenViking profile"
assert_eq "$default_conf" "$(_openviking_claude_cli_config /home/carlos/.dotfiles)" "Claude non-XBOL path uses default OpenViking profile"
assert_eq "xbol" "$(_openviking_opencode_account /home/carlos/Development/XBOL/xbol-api-admin)" "OpenCode XBOL child uses XBOL account"
assert_eq "iteramind-dev" "$(_openviking_opencode_account /home/carlos/Development/ITERAMIND)" "OpenCode Iteramind root uses Iteramind account"
assert_eq "iteramind-dev" "$(_openviking_opencode_account /home/carlos/Development/ITERAMIND/projects/example)" "OpenCode Iteramind child uses Iteramind account"
assert_eq "local-dev" "$(_openviking_opencode_account /home/carlos/.dotfiles)" "OpenCode other paths use default account"

print "ok"
