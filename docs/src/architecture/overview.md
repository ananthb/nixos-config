# Architecture Overview

## Repository layout

```
machines/
  flake.nix              # Entry point: inputs, host definitions, module exports
  modules/               # Reusable modules (exported via flake outputs)
    options.nix           # machines.* NixOS/Darwin option declarations
    home-options.nix      # machines.* home-manager option declarations
    nixos/                # NixOS module re-exports
    home/                 # Home-manager module re-exports
  hosts/                  # Per-host configurations (not exported)
    shared/               # Shared host modules (linux, darwin, cloud, etc.)
    endeavour/            # NixOS server (x86_64-linux)
    enterprise/           # NixOS workstation (x86_64-linux)
    stargazer/            # Raspberry Pi 4 (aarch64-linux)
    voyager/              # Raspberry Pi 4 (aarch64-linux)
    kedi-cloud-hetzner1/  # Hetzner Cloud server (x86_64-linux)
    discovery.nix         # macOS workstation (aarch64-darwin)
  home/                   # Home-manager user configs
    common.nix            # Base config (all hosts)
    shell.nix             # Fish + starship + tmux + tools
    dev.nix               # Personal dev tools (imports modules/home/dev.nix)
  services/               # NixOS service modules (not exported)
  lib/                    # Library modules and helpers
  secrets/                # Encrypted secrets (sops-nix)
  docs/                   # This documentation (mdBook)
```

## How hosts are built

The flake defines two helper functions:

- `mkNixosHost { hostname, system, extraModules }` builds a NixOS configuration. Each host imports `hosts/<hostname>/default.nix`, which in turn imports shared modules and services.
- `mkDarwinHost { hostname, system, extraModules }` builds a nix-darwin configuration.

Both pass `hostname`, `system`, `inputs`, and other values via `specialArgs` so modules can access them.

## Module composition

```
flake.nix
  └─ mkNixosHost
       └─ hosts/<hostname>/default.nix
            ├─ hosts/shared/linux.nix         (or cloud.nix for cloud hosts)
            │    ├─ modules/options.nix        (machines.* options)
            │    ├─ hosts/shared/nixos-common.nix
            │    │    ├─ sops-nix, vault-secrets, quadlet
            │    │    └─ lib/kedi-target.nix   (service target)
            │    ├─ lib/scripts.nix            (backup helpers)
            │    ├─ lib/tailscale-serve-config.nix
            │    ├─ lib/cftunnel.nix
            │    └─ home-manager
            │         ├─ home/common.nix → home/shell.nix
            │         └─ home/<hostname>.nix (or home/<hostname>/default.nix)
            └─ services/*.nix                 (per-host service selection)
```

## Shared nixpkgs evaluation

To reduce memory usage during flake evaluation, all hosts on the same architecture share a single `pkgsFor` evaluation. This is done via `nixpkgs.pkgs = pkgsFor system` in each host module, rather than letting each host instantiate its own nixpkgs.
