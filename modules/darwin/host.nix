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

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

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
