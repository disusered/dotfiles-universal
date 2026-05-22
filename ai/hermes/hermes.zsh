hermes-init() {
  local profile="${1:-default}"
  local hermes_home="$HOME/.hermes"

  if [[ "$profile" != "default" ]]; then
    hermes_home="$HOME/.hermes/profiles/$profile"
  fi

  op inject -i "$hermes_home/env.tpl" -o "$hermes_home/.env"
  chmod 600 "$hermes_home/.env"
}
