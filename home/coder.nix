# Coder dev-VM home profile. Reuses the shared dev environment (helix, fish +
# yazelix, git, direnv) but carries NO secrets: the microVM authenticates via
# the Coder agent / tailnet. If a workspace later needs heavyweight credentials,
# follow the Vault-approle pattern (a sops-encrypted approle decrypted at
# runtime, then secrets fetched from the platform Vault) rather than shipping
# sops material into this public, secret-free profile.
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ../modules/home/options.nix
    ../modules/home/shell.nix
    ../modules/home/dev.nix
  ];

  home = {
    # mkDefault so this profile works standalone (homeManagerConfiguration sets
    # these here) and as home-manager.users.coder inside nixosConfigurations.coder
    # (the NixOS HM module sets them from users.users.coder and wins).
    username = lib.mkDefault "coder";
    homeDirectory = lib.mkDefault "/home/coder";
    stateVersion = "24.05";

    packages = with pkgs; [
      coder
      delta
      devenv
      fd
      fzf
      gh
      git
      git-absorb
      glab
      jq
      lazygit
      mosh
      nix-output-monitor
      ripgrep
    ];
  };

  programs = {
    home-manager.enable = true;

    git = {
      settings.user = {
        name = "Ananth Bhaskararaman";
        email = "antsub@gmail.com";
        useConfigOnly = "true";
      };
      # dev.nix leaves git signing unset (mkDefault null); the VM has no
      # YubiKey, so keep commits unsigned here.
      signing.signByDefault = lib.mkForce false;
    };
  };
}
