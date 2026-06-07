# Getting Started

## Add the flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-config = {
      url = "github:ananthb/nixos-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

## Import NixOS modules

Import the default bundle (all modules) or pick individual ones:

```nix
# All NixOS modules
modules = [ nixos-config.nixosModules.default ];

# Or just what you need
modules = [
  nixos-config.nixosModules.options
  nixos-config.nixosModules.scripts
  nixos-config.nixosModules.rclone-sync
];
```

Then configure the options:

```nix
{
  machines.username = "alice";
  machines.timeZone = "America/New_York";
  machines.locale = "en_US.UTF-8";
}
```

## Import home-manager modules

Pass `inputs` via `extraSpecialArgs` (needed for nixvim):

```nix
home-manager = {
  extraSpecialArgs = { inherit inputs; };
  users.alice = {
    imports = [
      nixos-config.homeManagerModules.default  # shell + dev
    ];
  };
};
```

Or import just the shell:

```nix
imports = [ nixos-config.homeManagerModules.shell ];
```

## Dependencies

Not all modules are fully standalone. Some depend on `vault-secrets` (the HashiCorp Vault credential injection module) or on other modules from this flake.

| Module | Standalone? | Dependencies |
|--------|-------------|-------------|
| `homeManagerModules.shell` | Yes | None |
| `homeManagerModules.dev` | Yes | `nixvim` (provided transitively via this flake's inputs) |
| `nixosModules.nix-settings` | Yes | None |
| `nixosModules.service-target` | Yes | `nixosModules.options` (for `machines.serviceTarget.name`) |
| `nixosModules.tailscale-serve` | Yes | None |
| `nixosModules.rclone-sync` | No | Requires `nixosModules.scripts` (for `my-scripts.shell-helpers`) |
| `nixosModules.scripts` | No | Requires `vault-secrets` NixOS module (declares kopia/gcloud secrets) |
| `nixosModules.cftunnel` | No | Requires `vault-secrets` NixOS module (stores tunnel credentials) |

If you want to use `rclone-sync`, `scripts`, or `cftunnel`, you'll also need [vault-secrets](https://github.com/serokell/vault-secrets) in your flake inputs and imported into your NixOS configuration.

The home-manager modules (`shell`, `dev`) are fully independent and can be used in any home-manager setup without NixOS or vault-secrets.

### Service modules

The service modules in `services/` (Seafile, Jellyfin, Immich, arr stack, monitoring, etc.) are exported under names like `nixosModules.media-jellyfin`, `nixosModules.monitoring-grafana`, `nixosModules.seafile`, and so on — see the [NixOS Modules](nixos-modules.md) page for the full list. They were written for one specific fleet and bake in opinions (vault secret paths, domains, container images) that may not match yours; fork-and-customize is often the right path. The [Fork and Customize](../guides/fork-and-customize.md) guide walks through that.
