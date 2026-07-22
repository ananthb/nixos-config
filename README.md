# nixos-config

How I run my machines. It holds a shared Nix dev environment (fish, yazelix,
nixvim, git, direnv, starship, and CLI tools). It also holds the NixOS,
nix-darwin, and home-manager configs that consume that environment. These run
my laptop and my Coder dev VMs.

## Secrets

Secrets are sops-encrypted. Only public key material lives in this repo.
Heavyweight credentials aren't shipped here. They're fetched at runtime from
Vault using a sops-encrypted approle.

## License

GPLv3. See [LICENSE](https://github.com/ananthb/nixos-config/blob/main/LICENSE).
