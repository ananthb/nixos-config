{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.machines;
in {
  imports = [
    ../nixos/nix-settings.nix
  ];

  nix.settings.trusted-users = ["root" cfg.username];

  nix.gc.interval = {
    Hour = 3;
    Minute = 15;
    Weekday = 7;
  };

  # Set primary user because of the whole
  # 'run-services-as-root-for-better-multiuser-support' thing.
  system.primaryUser = cfg.username;

  # Rex prepends REX_BIN_DIR to PATH in every terminal it opens, but
  # nix-darwin's set-environment -- sourced by fish before any user config --
  # rebuilds PATH from a fixed list and throws that entry away. Running after
  # that reset puts it back, so `rex` resolves to the server the app is
  # actually running instead of vanishing. Skip when unset: outside Rex the
  # variable is empty, and prepending it would add an empty PATH entry.
  environment.interactiveShellInit = ''
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Manually set nixbld gid because this changed to 30000 by default.
  ids.gids.nixbld = 350;

  users.users.${cfg.username} = {
    name = cfg.username;
    home = "/Users/" + cfg.username;
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  services.prometheus.exporters.node.enable = true;
  users.users._prometheus-node-exporter.home = lib.mkForce "/private/var/lib/prometheus-node-exporter";

  home-manager = {
    backupFileExtension = "hm-backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit hostname pkgs system inputs;
      inherit (cfg) username;
    };
  };
}
