openchamber-init() {
  mkdir -p ~/.config/openchamber
  op read "op://Personal/OpenChamber UI/password" > ~/.config/openchamber/.ui-password
  op read "op://Personal/OpenChamber JWT/password" > ~/.config/openchamber/.jwt-secret
  chmod 600 ~/.config/openchamber/.ui-password ~/.config/openchamber/.jwt-secret
  systemctl --user daemon-reload
  systemctl --user enable --now openchamber-serve.service
  systemctl --user restart openchamber-serve.service
  echo "OpenChamber secrets materialized and service (re)started."
}
