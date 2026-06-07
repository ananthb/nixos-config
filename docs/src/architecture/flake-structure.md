# Flake Structure

## Inputs

Key dependencies:

| Input | Purpose |
|-------|---------|
| `nixpkgs` | Package set (nixos-unstable) |
| `home-manager` | User environment management |
| `nix-darwin` | macOS system configuration |
| `sops-nix` | Secrets decryption at activation |
| `vault-secrets` | HashiCorp Vault credential injection |
| `deploy-rs` | Remote NixOS deployment |
| `disko` | Declarative disk partitioning (used by nixos-anywhere installs) |
| `lanzaboote` | Secure Boot support |
| `nixvim` | Declarative Neovim configuration |
| `nixos-hardware` | Hardware-specific modules (RPi4) |
| `quadlet-nix` | Podman Quadlet container support |
| `git-hooks` | Pre-commit hooks (alejandra, statix, deadnix) |

All inputs follow `nixpkgs` to ensure a single package set.

## Outputs

### Host configurations

- `nixosConfigurations.{endeavour,enterprise,stargazer,voyager,kedi-cloud-hetzner1}`
- `darwinConfigurations.discovery`

### Reusable modules

- `nixosModules.default` — all NixOS modules bundled
- `nixosModules.{options,scripts,cftunnel,tailscale-serve,service-target,rclone-sync,nix-settings}` — individual modules
- `homeManagerModules.default` — shell + dev bundled
- `homeManagerModules.{options,shell,dev}` — individual modules

### Other outputs

- `packages.<system>.docs` — built mdBook documentation
- `apps.<system>.docs-serve` — live-reloading doc server
- `deploy.nodes` — deploy-rs remote deployment targets
- `checks.<system>` — formatting, linting, deploy verification
- `devShells.<system>.default` — development shell
- `formatter.<system>` — alejandra
- `lib.mkCaddyReverseProxies` — Caddy reverse proxy helper function
