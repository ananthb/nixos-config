# Monitoring

A full observability stack runs on the infrastructure: VictoriaMetrics for metrics storage, Grafana for dashboards and alerting, and Prometheus exporters on every host.

## VictoriaMetrics

Long-term metrics storage with 180-day retention. Scrapes Prometheus exporters every 10 seconds.

### Exporters scraped

| Exporter | What it monitors |
|----------|-----------------|
| Node Exporter | CPU, memory, disk, network per host |
| SmartCTL | Disk SMART health data |
| Blackbox | HTTP/HTTPS/ICMP probes for uptime monitoring |
| NUT | UPS battery and power status |
| EcoFlow | Portable battery system metrics (via MQTT) |
| Libvirt | Virtual machine resource usage |
| Postgres | Database connection and query metrics |
| Exportarr | Sonarr, Radarr, Prowlarr media app metrics |
| Speedtest | Internet speed measurements |

Custom metrics from backup jobs and rclone syncs are pushed directly via the VictoriaMetrics import API.

## Grafana

Dashboards and alerting with Google OAuth authentication.

### Alert rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| Application Down | HTTP probe returns non-2xx | Critical |
| SSL Certificate Expiring | Less than 7 days until expiry | Warning |
| Home Network Down | ICMP ping failure to routers/servers | Critical |
| UPS Power Loss | Input voltage below threshold | Critical |
| Disk Space Critical | Less than 10% free on root or data partitions | Critical |
| High Memory Pressure | Less than 10% available RAM | Warning |
| Systemd Service Failed | Any unit in failed state | Warning |
| Backup Stale | No successful backup in 48 hours | Warning |
| Internet Connectivity Lost | DNS probes failing to Google/Cloudflare | Critical |

Alerts route to Discord. A "night hours" muting schedule suppresses non-critical alerts during sleep.

## Probe infrastructure

Two distributed probing systems run on the network:

- **Starla** (RIPE Atlas software probe): Contributes to global internet measurement, exposes metrics on port 9695
- **Globalping**: Runs as a Podman container contributing to the Globalping distributed probe network
