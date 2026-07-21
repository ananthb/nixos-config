{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.machines;
in {
  # The shared darwin modules (options, host, homebrew, dev) are injected by
  # mkDarwinHost in flake.nix now that this host lives in-repo; only the
  # host-specific Determinate Nix module is imported here.
  imports = [
    inputs.determinate.darwinModules.default
  ];

  fonts.packages = [pkgs.hack-font];

  # This machine runs Determinate Nix, which manages its own daemon and
  # conflicts with nix-darwin's native Nix management. determinateNix.enable
  # hands the daemon and nix.conf to Determinate (replacing nix.enable =
  # false); customSettings re-declares the binary caches and trusted users
  # that nix.settings would otherwise no longer apply. The shared modules
  # enable automatic gc/optimise, which assert on nix.enable; force them off
  # since Determinate handles its own store maintenance.
  determinateNix = {
    enable = true;
    customSettings = {
      extra-substituters = [
        "https://ananthb.cachix.org"
        "https://nix-community.cachix.org"
        "https://lanzaboote.cachix.org"
        "https://yazelix.cachix.org"
      ];
      extra-trusted-public-keys = [
        "ananthb.cachix.org-1:3xWOBNIZww9cR1M82NgG4PtJ266LU9Ec30BrTON4ODA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lanzaboote.cachix.org-1:DaO+aH1QRT1iuKv/+/QqlqHwhBVm3sw5pZf//jPVRnA="
        "yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM="
      ];
      trusted-users = ["root" cfg.username];
    };
  };
  nix.gc.automatic = lib.mkForce false;
  nix.optimise.automatic = lib.mkForce false;

  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  services.karabiner-elements.enable = false;

  # Exclude codespace hosts (cs.* and cs-*) so cosmonaut's check
  # against bare `Host *` rules in ~/.ssh/config stays green.
  programs.ssh.extraConfig = ''
    Host * !cs-* !cs.*
      AddKeysToAgent yes
  '';

  # Make fish the default login shell. nix-darwin only changes a user's
  # shell when that user is in knownUsers, and it refuses to manage an
  # existing user unless the declared uid matches the real account (501
  # here; home comes from the shared host module). fish must also be in
  # /etc/shells to be a valid login shell.
  programs.fish.enable = true;
  environment.shells = [pkgs.fish];
  users.knownUsers = [cfg.username];
  users.users.${cfg.username} = {
    uid = 501;
    shell = pkgs.fish;
  };

  home-manager.users.${cfg.username} = {
    imports = let
      hostModule = (import ../lib/home-host-module.nix {inherit lib;}) hostname;
    in [
      ../home/common.nix
      ../home/dev.nix
      hostModule
    ];
  };
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.homeModules.nix-index
  ];

  nix-homebrew.user = cfg.username;
  nix-homebrew.taps."theseal/homebrew-ssh-askpass" = inputs.askpass-homebrew-tap;

  homebrew = {
    brews = [
      "container"
      "openssh" # needed for yubikey ssh keys
      "ssh-askpass"
    ];
    casks = [
      "1password"
      "claude"
      "claude-code"
      "codex"
      "codex-app"
      "discord"
      "drata-agent"
      "ghostty"
      "gimp"
      "google-chrome"
      "jellyfin-media-player"
      "ledger-wallet"
      "mac-mouse-fix"
      "openmtp"
      "raspberry-pi-imager"
      "rectangle-pro"
      "signal"
      "slack"
      "slack-cli"
      "visual-studio-code"
      "vlc"
      "yubico-authenticator"
    ];
    masApps = {
      "1Password for Safari" = 1569813296;
      "GarageBand" = 682658836;
      "iMovie" = 408981434;
      "Tailscale" = 1475387142;
      "Telegram" = 747648890;
      "Velja" = 1607635845;
      "WhatsApp" = 310633997;
    };
  };
}
