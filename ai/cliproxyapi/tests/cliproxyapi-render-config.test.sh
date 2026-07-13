#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
renderer="$repo_root/ai/cliproxyapi/scripts/cliproxyapi-render-config"
template="$repo_root/ai/cliproxyapi/config.yaml.tpl"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

home="$test_root/home"
stdout_file="$test_root/stdout"
stderr_file="$test_root/stderr"
mkdir -p "$home"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

assert_mode() {
  local expected=$1
  local path=$2
  local actual

  actual=$(stat -c '%a' "$path")
  [[ $actual == "$expected" ]] || fail "$path mode is $actual, expected $expected"
}

assert_line() {
  local expected=$1
  local path=$2

  grep -Fxq -- "$expected" "$path" || fail "$path is missing: $expected"
}

run_renderer() {
  env -u XDG_STATE_HOME \
    HOME="$home" \
    CLIPROXYAPI_CONFIG_TEMPLATE="$template" \
    bash "$renderer" >"$stdout_file" 2>"$stderr_file"
}

run_renderer

config_dir="$home/.cli-proxy-api"
config_file="$config_dir/config.yaml"
state_dir="$home/.local/state/cliproxyapi"
token_file="$state_dir/client-token"

[[ -f $config_file ]] || fail "renderer did not create config.yaml"
[[ -f $token_file ]] || fail "renderer did not create client-token"
assert_mode 700 "$config_dir"
assert_mode 700 "$state_dir"
assert_mode 600 "$config_file"
assert_mode 600 "$token_file"

client_token=$(<"$token_file")
[[ $client_token =~ ^sk-local-[0-9a-f]{64}$ ]] || fail "client token has the wrong format"
grep -Fq -- "$client_token" "$config_file" || fail "rendered config does not contain the client token"
[[ $(grep -Fo -- "$client_token" "$config_file" | wc -l) -eq 1 ]] ||
  fail "rendered config must contain the client token exactly once"
if grep -Fq -- '__CLIPROXYAPI_CLIENT_TOKEN__' "$config_file"; then
  fail "rendered config still contains the placeholder"
fi
if grep -Fq -- "$client_token" "$stdout_file" "$stderr_file"; then
  fail "renderer printed the client token"
fi

assert_line 'host: "127.0.0.1"' "$config_file"
assert_line 'port: 8317' "$config_file"
assert_line '  allow-remote: false' "$config_file"
assert_line '  secret-key: ""' "$config_file"
assert_line '  disable-control-panel: true' "$config_file"
assert_line 'auth-dir: "~/.cli-proxy-api"' "$config_file"
assert_line 'debug: false' "$config_file"
assert_line 'logging-to-file: false' "$config_file"
assert_line 'usage-statistics-enabled: false' "$config_file"
assert_line 'ws-auth: true' "$config_file"

cp "$config_file" "$test_root/expected-config"
chmod 755 "$config_dir" "$state_dir"
chmod 644 "$config_file" "$token_file"
run_renderer

[[ $(<"$token_file") == "$client_token" ]] || fail "renderer did not reuse the existing client token"
cmp -s "$test_root/expected-config" "$config_file" || fail "stable rerender changed config.yaml"
assert_mode 700 "$config_dir"
assert_mode 700 "$state_dir"
assert_mode 600 "$config_file"
assert_mode 600 "$token_file"
if grep -Fq -- "$client_token" "$stdout_file" "$stderr_file"; then
  fail "rerender printed the client token"
fi

bad_template="$test_root/bad-template.yaml"
printf 'host: "127.0.0.1"\n' >"$bad_template"
if env -u XDG_STATE_HOME \
  HOME="$home" \
  CLIPROXYAPI_CONFIG_TEMPLATE="$bad_template" \
  bash "$renderer" >"$stdout_file" 2>"$stderr_file"; then
  fail "renderer accepted a template without the placeholder"
fi
cmp -s "$test_root/expected-config" "$config_file" || fail "invalid template replaced config.yaml"
if grep -Fq -- "$client_token" "$stdout_file" "$stderr_file"; then
  fail "template validation failure printed the client token"
fi

printf '%s\n%s\n' '__CLIPROXYAPI_CLIENT_TOKEN__' '__CLIPROXYAPI_CLIENT_TOKEN__' >"$bad_template"
if env -u XDG_STATE_HOME \
  HOME="$home" \
  CLIPROXYAPI_CONFIG_TEMPLATE="$bad_template" \
  bash "$renderer" >"$stdout_file" 2>"$stderr_file"; then
  fail "renderer accepted a duplicate placeholder"
fi
cmp -s "$test_root/expected-config" "$config_file" || fail "duplicate placeholder replaced config.yaml"

printf 'invalid-token\n' >"$token_file"
if run_renderer; then
  fail "renderer accepted an invalid existing token"
fi
cmp -s "$test_root/expected-config" "$config_file" || fail "invalid token replaced config.yaml"
if grep -Fq -- 'invalid-token' "$stdout_file" "$stderr_file"; then
  fail "token validation failure printed the invalid token"
fi

if find "$config_dir" "$state_dir" -maxdepth 1 -type f -name '.*.tmp.*' -print -quit | grep -q .; then
  fail "renderer left a temporary file behind"
fi

printf 'ok\n'
