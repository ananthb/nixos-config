# NixOS Modules

## options

Declares the `machines.*` option namespace. Imported automatically by `default`.

See [Options Reference](options-reference.md) for the full list.

## scripts

Backup helpers and shell utilities for systemd services.

**Options:**
- `my-services.mkBackupService` — function to create kopia backup services with common boilerplate
- `my-scripts.victoriaMetricsHost` — host running VictoriaMetrics (for `write_metric` helper)
- `my-scripts.shell-helpers` — sourceable shell script with `die`, `write_metric`, and other utilities

**Usage:**
```nix
{
  my-scripts.victoriaMetricsHost = "monitoring-host";

  systemd.services.my-backup = config.my-services.mkBackupService {
    name = "my-backup";
    paths = [ "/var/lib/myapp" ];
    # ...
  };
}
```

## cftunnel

Declarative Cloudflare Tunnel configuration with automatic vault-secrets wiring.

**Options:**
- `my-services.cftunnelConfig` — list of tunnel configurations

**Usage:**
```nix
{
  my-services.cftunnelConfig = [
    {
      tunnelId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
      tunnelName = "my-tunnel";
      ingress = {
        "app.example.com" = "http://localhost:3000";
        "api.example.com" = "http://localhost:8080";
      };
    }
  ];
}
```

Credentials are automatically fetched from Vault via `vault-secrets.secrets.cloudflare-tunnel-<id>`.

## tailscale-serve

Applies a Tailscale serve configuration at boot.

**Options:**
- `my-services.tailscaleServeConfig` — Tailscale serve config (JSON-serializable attrset)

Requires `networking.hostName` to be set. Waits for tailscaled to reach "Running" state before applying.

## service-target

Groups systemd services under a common target for batch restart.

**Options:**
- `my-services.kediTargets` — attrset of service names to include (set to `true`)
- `my-services.restartUnits` — extra units to include
- `my-services.restartUnitsExclude` — units to exclude

The target name is configurable via `machines.serviceTarget.name` (default: `"kedi"`).

**Usage:**
```nix
{
  machines.serviceTarget.name = "mystack";
  my-services.kediTargets = {
    jellyfin = true;
    sonarr = true;
    radarr = true;
  };
}
# Creates mystack.target that wants jellyfin.service, sonarr.service, radarr.service
# Restart all: systemctl restart mystack.target
```

## rclone-sync

Declarative rclone sync and bisync jobs as systemd services with timers.

**Options:**
- `my-services.rclone-syncs.<name>` — sync job configuration

**Usage:**
```nix
{
  my-services.rclone-syncs.photos-backup = {
    type = "sync";  # or "bisync"
    source = "/home/user/Photos";
    destination = "gdrive:Backups/Photos";
    rcloneConfig = "/run/secrets/rclone/config";
    interval = "daily";
    excludePatterns = [ "*.tmp" ];
  };
}
```

Default exclude patterns cover macOS, Windows, and Linux system files.

## nix-settings

Shared Nix configuration: enables flakes, sets the Garnix binary cache, and other defaults.
