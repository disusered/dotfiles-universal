# XBOL observability

Local, container-first metrics stack for XBOL.

## Shape

```text
GCP Cloud Monitoring metrics
  -> Grafana Alloy prometheus.exporter.gcp
  -> VictoriaMetrics single-node
  -> Grafana Prometheus datasource
  -> Hermes/XBOT access through Grafana MCP in the `xbol` profile
```

Logs are intentionally out of scope for this module.

## Services

Quadlet units:

- `xbol-victoriametrics.service`
  - container: `xbol-victoriametrics`
  - local URL: `http://127.0.0.1:8428`
  - stores data under `~/.local/share/xbol-observability/victoriametrics`
- `xbol-alloy.service`
  - container: `xbol-alloy`
  - local URL: `http://127.0.0.1:12345`
  - reads only `~/.config/gcloud/application_default_credentials.json`
  - writes metrics to VictoriaMetrics through Prometheus remote write
- `xbol-grafana.service`
  - container: `xbol-grafana`
  - local URL: `http://127.0.0.1:43000`
  - datasource: `XBOL VictoriaMetrics`
  - runtime state: Podman named volume `xbol-grafana-data`

The Quadlet containers mount committed config directories directly from this repo rather than the Rotz-linked `~/.config/xbol-observability` paths. Container-visible absolute symlinks from Rotz links otherwise break Grafana provisioning.

## Auth boundary

The only GCP credential mounted into the stack is Carlos' ADC JSON file, and only the Alloy container receives it:

```text
~/.config/gcloud/application_default_credentials.json
  -> /tmp/gcloud_adc.json:ro
```

Grafana, VictoriaMetrics, Hermes, and the XBOL sandbox do not receive GCP credentials.

Longer term, replace Carlos' ADC with a dedicated read-only identity that has `roles/monitoring.viewer` only.

## Collected sources

Initial sources:

- GKE/Kubernetes container metrics for cluster `boletera-qa`
- Cloud SQL PostgreSQL metrics for database id `boletera-qa:boletera`

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
- Alloy UI: `http://127.0.0.1:12345`

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

The MCP server talks to Grafana, Grafana talks to VictoriaMetrics, and neither Hermes/XBOT nor the XBOL sandbox receives GCP credentials.

## Notes

The starter Grafana dashboard uses the expected Stackdriver-exporter metric name pattern. If a panel is empty, run `xbol-observability-smoke` and update the panel query to match the actual exported metric/label names.

Do not add Cloud Logging here. Logs require a separate security review because they may expose secrets, customer data, or broad operational context.
