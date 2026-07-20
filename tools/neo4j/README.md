# Neo4j

Neo4j Desktop plus a rootless, loopback-only Neo4j Community instance for local
derived knowledge graphs.

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
