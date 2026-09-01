# Coder dev-VM home profile. Gets the whole CLI env -- including git identity --
# from modules/home/dev.nix, and adds only what is true of this guest alone.
#
# Carries NO secrets: the microVM authenticates via the Coder agent / tailnet.
# If a workspace later needs heavyweight credentials, follow the Vault-approle
# pattern (a sops-encrypted approle decrypted at runtime, then secrets fetched
# from the platform Vault) rather than shipping sops material into this public,
# secret-free profile.
{
  inputs,
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
  };

  # dev.nix leaves git signing unset (mkDefault null); the VM has no YubiKey,
  # so keep commits unsigned here.
  programs.git.signing.signByDefault = lib.mkForce false;
}
