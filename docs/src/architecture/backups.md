# Backups

Backups use two systems: **Kopia** for snapshot-based backups to cloud storage, and **rclone** for bidirectional file sync.

## Kopia backups

Kopia backs up filesystem data to a GCS (Google Cloud Storage) bucket. The `mkBackupService` helper in `lib/scripts.nix` creates systemd services with common boilerplate.

### Snapshot workflow

1. Take a read-only filesystem snapshot (bcachefs or btrfs subvolume, timestamped)
2. Connect to the Kopia repository on GCS using service account credentials from vault-secrets
3. Create a Kopia snapshot of the mounted snapshot
4. Clean up the filesystem snapshot
5. Emit metrics to VictoriaMetrics at each stage

### mkBackupService

```nix
systemd.services.my-backup = config.my-services.mkBackupService {
  name = "my-backup";
  startAt = "daily";
  stopService = "myapp";  # optional: pause this service during backup
  script = ''
    ${config.my-scripts.kopia-snapshot-backup} /srv/myapp-data
  '';
};
```

The helper provides:
- Automatic service stop/start around the backup (if `stopService` is set)
- Kopia and shell helpers on PATH
- Update check suppression
- Oneshot service type with timer scheduling

### Metrics

Every backup emits Prometheus metrics to VictoriaMetrics:

| Metric | Labels | Meaning |
|--------|--------|---------|
| `kopia_backups_count` | `job`, `instance`, `stage` | Lifecycle tracking (fs_snapshot, kopia_connect, kopia_snapshot) |
| `kopia_backups_total` | `job`, `instance` | Timestamp of last successful backup |

Grafana alerts fire if no backup has completed in 48 hours.

## Rclone sync

The `rclone-sync` module (`lib/rclone-sync.nix`) provides declarative sync jobs as systemd services with timers.

### Sync modes

- **`sync`** (one-way): Source is authoritative. 4 parallel transfers, 8 checkers.
- **`bisync`** (two-way): Changes propagate both directions. Auto-detects first run and triggers `--resync`. Recovers automatically from critical state errors.

### Configuration

```nix
my-services.rclone-syncs.documents = {
  type = "bisync";
  source = "seafile:Documents";
  destination = "gdrive:Documents";
  rcloneConfig = "/run/secrets/rclone/config";
  interval = "*:0/5";  # every 5 minutes
  sizeOnly = true;     # ignore timestamps
  excludePatterns = [ "Backups/**" ];
};
```

### Default exclusions

All sync jobs automatically exclude OS junk files: `._*`, `.DS_Store`, `Thumbs.db`, `Desktop.ini`, `$RECYCLE.BIN`, `.Trash-*`, office lock files, and more.

### Metrics

| Metric | Labels | Meaning |
|--------|--------|---------|
| `rclone_sync_status` | `job`, `stage`, `type` | Status (start, complete, error) |
| `rclone_sync_last_success_timestamp` | `job` | Unix timestamp of last success |

### Monitoring

The `write_metric` shell helper sends metrics to VictoriaMetrics in Prometheus text format. If VictoriaMetrics is unreachable, metrics are silently dropped (2-second timeout) so backups still complete.
