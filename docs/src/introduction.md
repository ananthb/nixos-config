# Ananth's Machines

Reusable NixOS and home-manager modules for opinionated shell, editor, and infrastructure setups. By [Ananth Bhaskararaman](https://private.tech).

This flake exports modules you can import into your own Nix configurations: a batteries-included shell (fish, starship, tmux, zoxide, atuin), a full Neovim IDE (30+ plugins via nixvim), and NixOS infrastructure modules for Cloudflare tunnels, Tailscale, rclone sync, backup helpers, and more. It also serves as the source of truth for Ananth's personal fleet of NixOS servers, Raspberry Pis, and a macOS workstation.

## What's included

- **NixOS modules** for Cloudflare tunnels, Tailscale serve configs, rclone sync jobs, systemd service targets, backup helpers, and more.
- **Home-manager modules** for a batteries-included shell (fish + starship + tmux + zoxide + atuin + eza + bat) and a full Neovim IDE (nixvim with 30+ plugins, LSP, treesitter, telescope, harpoon).
- **Parameterized options** (`machines.*`) so you can override the username, timezone, locale, vault address, and other defaults.

## Quick start

Add this flake as an input and import the modules you want:

```nix
{
  inputs.machines.url = "github:ananthb/machines";

  outputs = { machines, nixpkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        machines.nixosModules.default
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
  machines.homeManagerModules.shell  # just the shell
  # or machines.homeManagerModules.default  # shell + neovim dev env
];
```

## License

GPLv3. See [LICENSE](https://github.com/ananthb/machines/blob/main/LICENSE).
