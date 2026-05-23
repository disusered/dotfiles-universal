# XBOL observability

Local, container-first metrics and logs stack for XBOL.

## Shape

```text
GCP Cloud Monitoring metrics
  -> Grafana Alloy prometheus.exporter.gcp
  -> VictoriaMetrics single-node
  -> Grafana Prometheus datasource
  -> Hermes/XBOT access through Grafana MCP in the `xbol` profile

GCP Cloud Logging entries
  -> host-side xbol-gcp-log-fetch using Carlos' existing gcloud auth
  -> local NDJSON spool under ~/.local/share/xbol-observability/log-spool
  -> Grafana Alloy loki.source.file
  -> local Loki single-node
  -> Grafana Loki datasource and log panels
  -> Hermes/XBOT access through Grafana MCP in the `xbol` profile
```

The log path intentionally uses a host-side fetcher instead of putting Google credentials into XBOT, Grafana, Loki, or the XBOL sandbox.

## Services

Quadlet units:

- `xbol-victoriametrics.service`
  - container: `xbol-victoriametrics`
  - local URL: `http://127.0.0.1:8428`
  - stores data under `~/.local/share/xbol-observability/victoriametrics`
- `xbol-loki.service`
  - container: `xbol-loki`
  - local URL: `http://127.0.0.1:3100`
  - stores data under `~/.local/share/xbol-observability/loki`
  - stores local logs only; it does not receive Google credentials
- `xbol-alloy.service`
  - container: `xbol-alloy`
  - local URL: `http://127.0.0.1:12345`
  - reads `~/.config/gcloud/application_default_credentials.json` only for the existing Cloud Monitoring metrics exporter
  - tails local GCP log spool files from `~/.local/share/xbol-observability/log-spool`
  - writes metrics to VictoriaMetrics through Prometheus remote write
  - writes logs to Loki through Loki push
- `xbol-grafana.service`
  - container: `xbol-grafana`
  - local URL: `http://127.0.0.1:43000`
  - datasources: `XBOL VictoriaMetrics`, `XBOL Loki`
  - runtime state: Podman named volume `xbol-grafana-data`

User systemd units:

- `xbol-gcp-log-fetch.service`
  - one-shot host-side fetch of narrowly scoped GCP logs
  - runs `~/.local/bin/xbol-gcp-log-fetch --once`
- `xbol-gcp-log-fetch.timer`
  - optional periodic fetch every ~2 minutes
  - not enabled automatically by this module; enable only after confirming the filters are acceptable

The Quadlet containers mount committed config directories directly from this repo rather than the Rotz-linked `~/.config/xbol-observability` paths. Container-visible absolute symlinks from Rotz links otherwise break Grafana provisioning.

## Auth boundary

The metrics path still mounts Carlos' ADC JSON into Alloy only:

```text
~/.config/gcloud/application_default_credentials.json
  -> /tmp/gcloud_adc.json:ro
```

Grafana, VictoriaMetrics, Loki, Hermes, and the XBOL sandbox do not receive GCP credentials.

The logs path does not add any new Google credential mount. `xbol-gcp-log-fetch` runs on the host as Carlos and uses existing `gcloud` auth, then writes local NDJSON spool files for Alloy to tail.

Longer term, replace Carlos' ADC with a dedicated read-only identity that has only the minimum monitoring/log-reading permissions. That requires admin support and is not assumed here.

## Collected sources

Initial metrics sources:

- GKE/Kubernetes container metrics for cluster `boletera-qa`
- Cloud SQL PostgreSQL metrics for database id `boletera-qa:boletera`

Initial log sources:

- GKE container logs for cluster `boletera-qa`
- Cloud SQL database logs for database id `boletera-qa:boletera`
- Cloud Audit Logs are excluded by default with `NOT logName:"cloudaudit.googleapis.com"`

The Cloud SQL instance was discovered with:

```bash
gcloud sql instances list --project=boletera-qa
```

Current discovered instance:

```text
name: boletera
region: northamerica-south1
databaseVersion: POSTGRES_16
state: RUNNABLE
```

## Install/apply

From the dotfiles repo:

```bash
~/.rotz/bin/rotz install /ai/xbol-observability
```

Then run:

```bash
xbol-observability-smoke
```

Useful URLs:

- Grafana: `http://127.0.0.1:43000`
- Tailnet Grafana: `http://xbol.disusered.com`
- VictoriaMetrics UI: `http://127.0.0.1:8428/vmui/`
- Loki labels API: `http://127.0.0.1:3100/loki/api/v1/labels`
- Alloy UI: `http://127.0.0.1:12345`

## Log fetcher

Dry-run without writing spool/state:

```bash
xbol-gcp-log-fetch --dry-run --limit 5
```

Fetch once and write local spool files:

```bash
xbol-gcp-log-fetch --once --limit 50
```

Enable periodic fetching only after confirming the filters are acceptable:

```bash
systemctl --user enable --now xbol-gcp-log-fetch.timer
```

Inspect timer/service state:

```bash
systemctl --user status xbol-gcp-log-fetch.timer xbol-gcp-log-fetch.service
```

Default locations:

- State: `~/.local/share/xbol-observability/log-fetch/state.json`
- Spool: `~/.local/share/xbol-observability/log-spool/cloudlogging/YYYY-MM-DD.ndjson`

Useful overrides:

- `XBOL_GCP_PROJECT`
- `XBOL_GCP_LOG_FILTER`
- `XBOL_GCP_LOG_EXCLUDE_FILTER`
- `XBOL_GCP_LOG_LIMIT`
- `XBOL_GCP_LOG_LOOKBACK_MINUTES`
- `XBOL_GCP_LOG_OVERLAP_MINUTES`
- `XBOL_LOG_FETCH_STATE_DIR`
- `XBOL_LOG_SPOOL_DIR`

## Hermes/XBOT access

The managed XBOL Hermes profile configures the Grafana MCP server against local Grafana:

```yaml
mcp_servers:
  grafana:
    command: uvx
    args:
    - mcp-grafana
    env:
      GRAFANA_URL: http://127.0.0.1:43000
```

The MCP server talks to Grafana. Grafana talks to VictoriaMetrics and Loki. Neither Hermes/XBOT nor the XBOL sandbox receives GCP credentials.

## Notes

The starter Grafana metrics dashboard uses the expected Stackdriver-exporter metric name pattern. If a panel is empty, run `xbol-observability-smoke` and update the panel query to match the actual exported metric/label names.

The starter Grafana logs dashboard uses the Loki datasource UID `xbol-loki` and LogQL selector `{job="xbol/gcp-cloudlogging"}`. It will be empty until `xbol-gcp-log-fetch` writes spool files and Alloy ships them to Loki.

Logs are sensitive. They may contain customer data, credentials, request payloads, or operational context. Keep the fetcher filters narrow, exclude audit logs by default, and do not expose GCP credentials to the XBOL sandbox or public-facing bot process.

If logs are already exported to Cloud Storage buckets, prefer a host-side bucket download/normalization extension to `xbol-gcp-log-fetch`; still expose only local normalized spool files to Alloy.
