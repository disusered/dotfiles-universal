#!/usr/bin/env bash
# Create one passphrase-less signing key per agent harness and trust it for
# local `git verify-commit`. GitHub still needs each .pub added as a signing key.
set -euo pipefail

key_dir="$HOME/.ssh/agents"
signers="$HOME/.ssh/allowed_signers"
principals="crosquillas@gmail.com,carlos@iteramind.com,carlos.rosquillas@odasoft.com.mx"

mkdir -p "$key_dir"
chmod 700 "$key_dir"
touch "$signers"

for agent in claude codex antigravity; do
  key="$key_dir/$agent"
  if [ ! -f "$key" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "$agent-signing" -f "$key"
  fi
  chmod 600 "$key"
  pub="$(cut -d' ' -f1,2 "$key.pub")"
  if ! grep -qF "$pub" "$signers"; then
    printf '%s namespaces="git" %s %s-signing\n' "$principals" "$pub" "$agent" >> "$signers"
  fi
done
