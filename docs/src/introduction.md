# nixos-config

Reusable NixOS, nix-darwin, and home-manager modules by [Ananth Bhaskararaman](https://private.tech).

This flake exports modules you can import into your own Nix configurations: a complete dev environment (fish + a yazelix zellij/yazi workspace + nixvim with 30+ plugins), a minimal bash baseline, and NixOS infrastructure modules for Cloudflare tunnels, Tailscale, rclone sync, backup helpers, and more.

## What's included

- **NixOS modules** for Cloudflare tunnels, Tailscale serve configs, rclone sync jobs, systemd service targets, backup helpers, and a curated set of self-hosted services (Immich, Jellyfin, Frigate, VictoriaMetrics, Grafana, Vaultwarden, Mealie, Actual, Seafile, …).
- **Home-manager modules**: a minimal `shell` (bash + history + aliases) and a `dev` that bundles fish + starship + yazelix (zellij + yazi) + nixvim with 30+ plugins + the usual CLI sidekicks (atuin, bat, eza, fd, fzf, gh, glab, gpg, lazygit, ripgrep, zoxide, delta).
- **Parameterized options** (`machines.*`) so you can override the username, timezone, locale, vault address, and other defaults.

## Quick start

Add this flake as an input and import the modules you want:

```nix
{
  inputs.nixos-config.url = "github:ananthb/nixos-config";

  outputs = { nixos-config, nixpkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-config.nixosModules.default
        {
          machines.username = "alice";
          machines.timeZone = "America/New_York";
        }
      ];
    };
  };
}
```

For home-manager only:

```nix
home-manager.sharedModules = [
  nixos-config.homeManagerModules.shell  # minimal bash
  # or nixos-config.homeManagerModules.dev  # fish + yazelix + nixvim + tools
  # or nixos-config.homeManagerModules.default  # shell + dev together
];
```

## License

GPLv3. See [LICENSE](https://github.com/ananthb/nixos-config/blob/main/LICENSE).
