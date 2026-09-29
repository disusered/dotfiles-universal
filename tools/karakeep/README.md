# Karakeep

Rotz-managed personal capture library. Karakeep 0.33.2 uses a rootless Podman network with a pinned Chrome crawler and Meilisearch 1.41.0. The web app binds only to `127.0.0.1:43130`; Caddy routes `https://karakeep.disusered.com` on the personal tailnet. DNS is owned by Cat Infra and applied through its CI.

## Install

```sh
~/.rotz/bin/rotz install /tools/karakeep
~/.rotz/bin/rotz install /tools/caddy
```

The installer initializes private env files only when neither exists, links Quadlets and the CLI, installs the pinned upstream CLI, starts Karakeep and enables a daily backup timer. Podman is a declared dependency. Existing secrets are preserved on reinstall. Config and data live outside Git:

- `~/.config/karakeep/server.env` and `search.env`: private service configuration.
- `~/.config/karakeep/api.env`: agent API endpoint and scoped key after account provisioning.
- `~/.local/share/karakeep/data`: database, original uploads, extracted text and archived pages.
- `~/.local/share/karakeep/search`: rebuildable full-text index.
- `~/.local/share/karakeep/backups`: private complete data/config archives.

Full-page Monolith archiving and screenshots are enabled. English and Spanish OCR use Tesseract. AI tagging/summarization are disabled; no model API is needed to save, read or search. Signups are disabled outside initial owner-account provisioning. Credentials belong in Personal/Karakeep in 1Password.

## Daily use

Save an open webpage using the Karakeep browser extension. On a phone connected to the personal tailnet, share to the Karakeep app. Upload PDFs and screenshots directly to Karakeep. Read and highlight there; open Atlas only when writing from saved material.

Configure clients with `https://karakeep.disusered.com` and your Karakeep login. An agent can capture an explicitly requested batch through the installed `karakeep` command; see [AGENT-USAGE.md](AGENT-USAGE.md). A successful bookmark write and a completed archive are separate outcomes.

## Operations

```sh
systemctl --user status karakeep.service karakeep-chrome.service karakeep-search.service
curl --fail http://127.0.0.1:43130/api/health
systemctl --user start karakeep-backup.service
```

The daily 04:20 backup briefly stops the Karakeep app so its database and assets are consistent, archives data and private configuration, then restarts it. Search is excluded because it can be rebuilt. Backups remain on this machine and have no automatic deletion; arrange off-device storage separately. Treat backups as credentials-bearing private files.

To restore, stop Karakeep, preserve the current data/config, extract a selected backup under the same home directory, and restart. Rebuild the search index through Karakeep administration. Do not restore over a running application.

Pin upgrades in the Quadlet images and `dot.yaml`; update the wrapper CLI pin together. Crawler is digest-pinned. Re-run the Rotz module after reviewing an upgrade.
