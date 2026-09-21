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
  pkgs,
  ...
}: let
  # Push to the forge with the token Nomad rendered into this workspace's
  # environment for its owner (calculon-tech/platform,
  # tf/forgejo/workspace-tokens.tf). Declared per-host rather than in
  # modules/home/dev.nix because FORGEJO_TOKEN exists only here; on the Mac
  # and the Chromebook the forge credential is still whatever `fj` wrote.
  #
  # Quiet when the variable is absent, so a `docker run` of this image by
  # hand, or a shell that did not inherit it, falls through to git's other
  # helpers instead of answering with an empty password.
  #
  # `store` is deliberately not used and neither is a file: the token is
  # already in the environment, it is rotated by re-minting in Vault, and a
  # copy on the persistent volume would outlive that.
  forgejoCredential = pkgs.writeShellScript "git-credential-forgejo-workspace" ''
    [ "''${1:-}" = get ] || exit 0
    [ -n "''${FORGEJO_TOKEN:-}" ] || exit 0
    printf 'username=%s\npassword=%s\n' "''${FORGEJO_USER:-git}" "$FORGEJO_TOKEN"
  '';
in {
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

  # Scoped to the forge's origin, so it is consulted for calculon.tech and
  # nothing else; github.com still goes through `gh auth git-credential`.
  # User-level, which is the point: the per-checkout `git config --local
  # credential.helper` dance was the friction this removes.
  programs.git.settings.credential."https://calculon.tech".helper = "${forgejoCredential}";

  dev.helix.disable = ["c" "ltex" "ansible"];
}
