# Fork and Customize

This guide walks through forking this repository and making it your own.

## 1. Fork the repo

```bash
gh repo fork ananthb/machines --clone
cd machines
```

## 2. Set your identity

Edit `modules/options.nix` to change the defaults:

```nix
machines.username = mkOption {
  default = "yourname";  # was "ananth"
};

machines.sshKeys = mkOption {
  default = [
    "ssh-ed25519 AAAA... you@host"
  ];
};

machines.timeZone = mkOption {
  default = "America/New_York";  # was "Asia/Kolkata"
};

machines.locale = mkOption {
  default = "en_US.UTF-8";  # was "en_IN"
};
```

Update `modules/home-options.nix` similarly.

## 3. Set your git identity

Edit `home/dev.nix`:

```nix
programs.git.settings.user = {
  name = "Your Name";
  email = "you@example.com";
};
```

## 4. Remove personal hosts

Delete the host directories you don't need:

```bash
rm -rf hosts/endeavour hosts/enterprise hosts/stargazer hosts/voyager
rm -rf hosts/kedi-cloud-hetzner1 hosts/discovery.nix
rm -rf home/endeavour.nix home/discovery.nix home/stargazer.nix
rm -rf home/voyager.nix home/enterprise/
```

Remove the corresponding entries from `flake.nix`:
- `nixosConfigurations.*`
- `darwinConfigurations.*`
- `deploy.nodes.*`

## 5. Add your first host

Create `hosts/myhost/default.nix`:

```nix
{
  config,
  hostname,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ../shared/linux.nix
    ./hardware-configuration.nix
    # Add service modules as needed:
    # ../../services/caddy.nix
  ];

  # Host-specific configuration
  networking.hostName = hostname;
}
```

Generate hardware config:

```bash
nixos-generate-config --show-hardware-config > hosts/myhost/hardware-configuration.nix
```

Create a minimal home config at `home/myhost.nix`:

```nix
{...}: {
  imports = [./dev.nix];
}
```

Add to `flake.nix`:

```nix
nixosConfigurations.myhost = mkNixosHost {
  hostname = "myhost";
  system = "x86_64-linux";
};
```

## 6. Set up secrets

Create a new `.sops.yaml` with your own age/PGP keys. Create `secrets/myhost.yaml` with your host's secrets.

If you don't use Vault, remove `vault-secrets` from `hosts/shared/nixos-common.nix` and the corresponding flake input.

## 7. Remove unused flake inputs

Review `flake.nix` inputs and remove anything you don't use (e.g., `lanzaboote` if you don't need secure boot, `nix-homebrew` if you don't have a Mac, etc.).

## 8. Build and test

```bash
nix build .#nixosConfigurations.myhost.config.system.build.toplevel
```

## Using modules without forking

If you just want the shell or dev environment without managing hosts, use the flake as an input:

```nix
{
  inputs.machines.url = "github:ananthb/machines";

  outputs = { machines, ... }: {
    # Use in your own NixOS config
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        machines.nixosModules.options
        machines.nixosModules.scripts
        { machines.username = "you"; }
      ];
    };

    # Or just the home-manager modules
    homeConfigurations.you = home-manager.lib.homeManagerConfiguration {
      modules = [
        machines.homeManagerModules.shell
      ];
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
```
