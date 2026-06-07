# Getting Started

## Add the flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    machines = {
      url = "github:ananthb/machines";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

## Import NixOS modules

Import the default bundle (all modules) or pick individual ones:

```nix
# All NixOS modules
modules = [ machines.nixosModules.default ];

# Or just what you need
modules = [
  machines.nixosModules.options
  machines.nixosModules.scripts
  machines.nixosModules.rclone-sync
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
      machines.homeManagerModules.default  # shell + dev
    ];
  };
};
```

Or import just the shell:

```nix
imports = [ machines.homeManagerModules.shell ];
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

### What's not exported

Service modules in `services/` (Seafile, Jellyfin, Immich, arr stack, monitoring, etc.) are not exported as flake modules. They contain host-specific configuration (domains, vault secret paths, container images) that makes them hard to generalize. If you want to reuse one of these, fork the repo and adapt the service file directly. The [Fork and Customize](../guides/fork-and-customize.md) guide walks through this.
