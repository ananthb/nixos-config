# nixos-config

How I run my machines: a shared Nix dev environment (fish + yazelix + nixvim,
git, direnv, starship, CLI tools) plus the NixOS, nix-darwin, and home-manager
configs that consume it — my laptop and my Coder dev VMs.

Server and hosting infrastructure lives in
[private-tech/platform](https://github.com/private-tech/platform).

## Secrets

Secrets are sops-encrypted; only public key material lives in this repo.
Heavyweight credentials aren't shipped here — they're fetched at runtime from
Vault via a sops-encrypted approle.

## License

GPLv3. See [LICENSE](https://github.com/ananthb/nixos-config/blob/main/LICENSE).
