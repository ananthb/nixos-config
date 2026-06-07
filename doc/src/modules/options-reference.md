# Options Reference

All options are under the `machines` namespace.

## NixOS / nix-darwin options

Declared in `modules/options.nix`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `machines.username` | `str` | `"ananth"` | Primary user account name |
| `machines.sshKeys` | `listOf str` | Yubikey keys | SSH public keys for the primary user |
| `machines.timeZone` | `str` | `"Asia/Kolkata"` | System timezone |
| `machines.locale` | `str` | `"en_IN"` | System default locale |
| `machines.vault.address` | `str` | `"http://endeavour:8200"` | Vault server address |
| `machines.monitoring.vmHost` | `nullOr str` | `"endeavour"` | Host running VictoriaMetrics |
| `machines.serviceTarget.name` | `str` | `"kedi"` | Systemd target name for grouped services |

## Home-manager options

Declared in `modules/home-options.nix`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `machines.username` | `str` | `"ananth"` | Primary user account name |

## Service-level options

These are declared by the individual NixOS modules and live under `my-services.*` and `my-scripts.*`:

| Option | Module | Type | Description |
|--------|--------|------|-------------|
| `my-services.cftunnelConfig` | cftunnel | `nullOr (listOf tunnel)` | Cloudflare tunnel configs |
| `my-services.tailscaleServeConfig` | tailscale-serve | `nullOr attrs` | Tailscale serve config |
| `my-services.kediTargets` | service-target | `attrsOf bool` | Services for the grouped target |
| `my-services.restartUnits` | service-target | `listOf str` | Extra units for the target |
| `my-services.restartUnitsExclude` | service-target | `listOf str` | Units to exclude from the target |
| `my-services.rclone-syncs` | rclone-sync | `attrsOf syncJob` | Rclone sync job definitions |
| `my-services.mkBackupService` | scripts | `functionTo attrs` | Kopia backup service builder |
| `my-scripts.victoriaMetricsHost` | scripts | `nullOr str` | VictoriaMetrics host for metrics |
| `my-scripts.shell-helpers` | scripts | `package` | Sourceable shell helpers script |
