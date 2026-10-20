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

Full-page Monolith archiving and screenshots are enabled. English and Spanish OCR use Tesseract. The built-in AI tagger uses DeepSeek's `deepseek-flash` through the existing ordinary API key in 1Password. AI summaries, LLM OCR, and automatic embedding generation remain disabled. Signups are disabled outside initial owner-account provisioning. Karakeep account credentials belong in Personal/Karakeep; the provider key belongs in Personal/Deepseek in 1Password.

The repository and 1Password configuration contain no separate RapidSeek endpoint or credential. Existing notes use "RapidSeek" alongside DeepSeek without resolving a distinct provider; this deployment therefore uses the configured DeepSeek API directly.

## AI tagging

The provider configuration is kept separately from the application env:

- `inference.env.tpl` is the committed template containing the 1Password reference and non-secret AI settings.
- `~/.config/karakeep/inference.env` is the rendered private configuration. It must be owned by the current user with mode 0600.

Render or refresh it after changing the template:

```sh
op inject --file-mode 0600 --force \
  --in-file ~/.dotfiles/tools/karakeep/inference.env.tpl \
  --out-file ~/.config/karakeep/inference.env
systemctl --user daemon-reload
systemctl --user restart karakeep.service
```

Karakeep sends the bookmark URL, title, description, and extracted plain-text content to DeepSeek for link tagging. Notes send their body, PDFs send extracted text, and image bookmarks send the image bytes plus the tagging prompt. `INFERENCE_CONTEXT_LENGTH=2048` truncates text input. `EMBEDDING_ENABLE_AUTO_INDEXING=false` prevents semantic-search embeddings from being generated during tagging.

At DeepSeek's off-peak prices on 2026-10-20, `deepseek-flash` costs $0.15 per million cache-miss input tokens and $0.60 per million output tokens; peak rates are double, while cache hits cost $0.003-$0.006 per million tokens. A text bookmark using the full configured context and output budget would cost at most about $0.00061 off-peak; typical short bookmarks cost much less. Image input is billed by its token count. These are estimates, not a spending cap.

This deployment calls DeepSeek directly. The proposed `cats-llm-proxy` audit and usage-control layer is not implemented, so Karakeep requests bypass that future proxy coverage. Point `OPENAI_BASE_URL` at the approved proxy only after it supports the required model, JSON mode, usage accounting, and failure behavior.

Enable or disable tagging for new bookmarks in Karakeep under User Settings > AI. Do not use the admin bulk-retag action unless explicitly intended; it sends the whole archive to the provider.

To roll back this integration, restore the saved `karakeep.container` and `server.env` from the timestamped backup, remove `~/.config/karakeep/inference.env`, then run `systemctl --user daemon-reload` and `systemctl --user restart karakeep.service`. Removing the extra `EnvironmentFile` line alone is enough to stop the provider configuration from loading; the env file contains the API key and must remain mode 0600 while present.

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
