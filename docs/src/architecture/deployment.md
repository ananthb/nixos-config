# Deployment

## deploy-rs

All NixOS hosts (local and cloud) are deployed via deploy-rs over SSH:

```bash
# Deploy all hosts
nix run .#deploy-rs

# Deploy a specific host
nix run .#deploy-rs -- .#endeavour
```

Hosts connect over Tailscale. The deploy user is `root` with SSH key authentication.

## Auto-upgrade

NixOS hosts auto-upgrade nightly at 02:00 (with up to 45min random delay) using `system.autoUpgrade`. They rebuild from the flake's current state.

## CI pipeline

The GitHub Actions workflow (`deploy.yml`) runs on push to `main`:

1. **tailscale-acl** — applies Tailscale ACL policy
2. **deploy** — runs deploy-rs with `--skip-checks --remote-build`

The pipeline connects to hosts via Tailscale and deploys using SSH.
