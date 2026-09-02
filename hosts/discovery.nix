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

  # Hack Nerd Font, not plain Hack. zellij's UI separators and eza's
  # `icons = "auto"` both draw from the Nerd Font private-use range, which
  # stock Hack does not carry -- they render as blank boxes. Same family,
  # patched glyphs. This is the copy that matters: nix-darwin puts it in
  # /Library/Fonts where macOS apps actually look, whereas a font in
  # home.packages only lands in the nix profile.
  fonts.packages = [pkgs.nerd-fonts.hack];

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
      ];
      extra-trusted-public-keys = [
        "ananthb.cachix.org-1:3xWOBNIZww9cR1M82NgG4PtJ266LU9Ec30BrTON4ODA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lanzaboote.cachix.org-1:DaO+aH1QRT1iuKv/+/QqlqHwhBVm3sw5pZf//jPVRnA="
      ];
      trusted-users = ["root" cfg.username];
    };
  };
  nix.gc.automatic = lib.mkForce false;
  nix.optimise.automatic = lib.mkForce false;

  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;

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
      ../modules/home/options.nix
      ../modules/home/shell.nix
      ../modules/home/dev.nix
      hostModule
    ];
  };
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.homeModules.nix-index
  ];

  nix-homebrew.user = cfg.username;
  nix-homebrew.taps."theseal/homebrew-ssh-askpass" = inputs.askpass-homebrew-tap;

  # Homebrew 4 refuses to load a formula from a third-party tap until the tap is
  # trusted, and `brew bundle` aborts on the first untrusted one -- so a single
  # unblessed tap takes the rest of the activation down with it, which is how
  # this surfaced: everything after ssh-askpass silently stopped applying.
  #
  # preActivation runs before the homebrew activation script (nix-darwin orders
  # preActivation, extraActivation, then homebrew), so the trust is in place by
  # the time bundle runs. Invoked as the brew user the same way nix-darwin
  # invokes bundle itself; activation runs as root and brew refuses that.
  system.activationScripts.preActivation.text = ''
    if [ -x /opt/homebrew/bin/brew ]; then
      sudo --user=${cfg.username} --set-home /opt/homebrew/bin/brew trust theseal/ssh-askpass \
        >/dev/null 2>&1 || true
    fi
  '';

  homebrew = {
    brews = [
      "container"
      "openssh" # needed for yubikey ssh keys
      "ssh-askpass"
    ];
    casks = [
      "1password"
      # "claude" is the desktop app. claude-code is NOT here on purpose: it
      # comes from nixpkgs via modules/home/dev.nix, so darwin, the Coder
      # workspace and the chromebook all run the same build. Neither Linux
      # profile has Homebrew, so a cask here could only ever mean this Mac
      # drifting to a different version than the workspace. The trade is that
      # updates arrive with `nix flake update` rather than the app updating
      # itself -- a store install cannot self-update.
      "claude"
      "codex"
      "codex-app"
      "discord"
      "drata-agent"
      # GUI apps stay casks. macOS wants a real .app bundle in /Applications
      # -- Launchpad, Spotlight, the dock and `open -a` all key off it, and a
      # nixpkgs build lands in the store instead. That is the split: GUI here,
      # CLI from nixpkgs via modules/home/dev.nix (see claude-code above).
      # Ghostty is also the terminal, so it is what has to carry the Hack Nerd
      # Font -- set `font-family = "Hack Nerd Font Mono"` in its config.
      "ghostty"
      "gimp"
      "google-chrome"
      "jellyfin-media-player"
      "openlogi"
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
      "Velja" = 1607635845;
      "WhatsApp" = 310633997;
    };
  };
}
