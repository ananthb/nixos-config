# Personal development config: git identity, sops secrets, personal packages.
# Reusable dev tooling (nixvim, git settings, direnv) lives in modules/home/dev.nix.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  imports = [
    ../modules/home/dev.nix
    inputs.cosmonaut.homeManagerModules.default
  ];

  sops = {
    age.sshKeyPaths = [(homeDir + "/.ssh/id_ed25519")];
    defaultSopsFile = ../secrets/dev.yaml;

    secrets = {
      "ssh/yubikey_5c" = {
        path = homeDir + "/.ssh/yubikey_5c";
      };
      "ssh/yubikey_5c.pub" = {
        path = homeDir + "/.ssh/yubikey_5c.pub";
      };
      "ssh/yubikey_5c_nano" = {
        path = homeDir + "/.ssh/yubikey_5c_nano";
      };
      "ssh/yubikey_5c_nano.pub" = {
        path = homeDir + "/.ssh/yubikey_5c_nano.pub";
      };
    };
  };

  # Fix for sops-nix LaunchAgent on macOS.
  launchd.agents.sops-nix = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      EnvironmentVariables = {
        PATH = pkgs.lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  home = {
    packages = with pkgs;
      [
        coder
        delta
        devenv
        flyctl
        fzf
        gemini-cli
        gh
        git-absorb
        git
        glab
        gnupg
        hack-font
        hcloud
        lazygit
        mosh
        nix-output-monitor
        ripgrep
        sops
        ssh-to-age
        vault
        zed-editor
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        pinentry_mac
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        claude-code
        ghostty
        gimp
        jellyfin-media-player
        rpi-imager
        vlc
        vscode
      ];

    # On macOS, home-manager's services.gpg-agent is unavailable (it is
    # systemd-only), so point gpg-agent at pinentry-mac directly. Needed for
    # YubiKey PIN prompts, e.g. `sops updatekeys` with the admin PGP key.
    file.".gnupg/gpg-agent.conf" = lib.mkIf pkgs.stdenv.isDarwin {
      text = ''
        pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
        default-cache-ttl 600
        max-cache-ttl 7200
      '';
    };
  };

  programs = {
    git.settings.user = {
      name = "Ananth Bhaskararaman";
      email = "antsub@gmail.com";
      useConfigOnly = "true";
    };

    cosmonaut = {
      enable = true;
      defaultTarget = "rpcpool";
      targets.rpcpool = {
        repository = "rpcpool/rpcpool";
        workspacePath = "/workspaces";
      };
    };

    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 30d";
      };
    };

    # Admin PGP key. Importing it declaratively means `sops updatekeys`
    # can find it after a fresh setup without a manual `gpg --recv-keys`.
    gpg.publicKeys = [
      {
        source = ./keys/admin_ananth.asc;
        trust = "ultimate";
      }
    ];
  };

  home.file.".claude/settings.json".text = builtins.toJSON {
    includeCoAuthoredBy = false;
    permissions.defaultMode = "auto";
    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
    };
    skipAutoPermissionPrompt = true;
    skipWorkflowUsageWarning = true;
  };
}
