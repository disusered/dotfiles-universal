openviking-health() {
  curl -fsS http://127.0.0.1:1933/health
}

openviking-ready() {
  curl -fsS http://127.0.0.1:1933/ready
}

openviking-init() {
  podman run --rm -it --network=host \
    -e OPENVIKING_CONFIG_FILE=/app/.openviking/ov.conf \
    -e OPENVIKING_SERVER_HOST=127.0.0.1 \
    -v "$HOME/.openviking:/app/.openviking:Z" \
    -v "$HOME/.local/share/openviking:/app/.openviking/data:Z" \
    ghcr.io/volcengine/openviking:latest \
    openviking-server init "$@"
}

openviking-doctor() {
  podman run --rm --network=host \
    -e OPENVIKING_CONFIG_FILE=/app/.openviking/ov.conf \
    -e OPENVIKING_SERVER_HOST=127.0.0.1 \
    -v "$HOME/.openviking:/app/.openviking:Z" \
    -v "$HOME/.local/share/openviking:/app/.openviking/data:Z" \
    ghcr.io/volcengine/openviking:latest \
    openviking-server doctor "$@"
}
