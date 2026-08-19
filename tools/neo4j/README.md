# Neo4j

Neo4j Desktop plus a rootless, loopback-only Neo4j Community instance for local
derived knowledge graphs.

## Not installed

Removed from the workstation on 2026-08-19. Its only consumer was
`XBOL/scripts/xbol-index`, which pipes CocoIndex into this graph, and XBOL work
is no longer hosted here. CocoIndex was also uninstalled; it never proved its
value next to OKF and OpenViking.

The module is kept so the service can be stood up elsewhere. Its Rotz recipe is
held as `dot.yaml.disabled` so an install cannot bring it back by accident.
Rename it to `dot.yaml` to deploy. The `Neo4j Local` 1Password item was left in
place.

The Rotz install creates or repairs a `Neo4j Local` login in the Personal
1Password vault, renders `~/.config/neo4j/neo4j.env` with mode `0600`, and
starts the `neo4j.service` user unit. Data and logs use persistent Podman named
volumes. No plugins are installed. On Arch Linux, it also installs Neo4j Desktop
from the AUR for managing and exploring local or remote graph databases.

```bash
~/.rotz/bin/rotz link /tools/neo4j -f
neo4j-init
systemctl --user daemon-reload
systemctl --user restart neo4j.service
neo4j-smoke
```

The browser is available only at `http://127.0.0.1:7474`; Bolt is available at
`bolt://127.0.0.1:7687`.
