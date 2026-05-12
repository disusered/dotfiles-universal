#!/usr/bin/env bash
set -euo pipefail

tailscale serve --bg --https=3014 3014
tailscale serve --bg --tcp=3307 localhost:3307
