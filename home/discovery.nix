# discovery (nix-darwin) host layer.
#
# This is the ONLY profile carrying secrets, because it is the only host with
# key material: the sops age key is derived from ~/.ssh/id_ed25519 and the
# YubiKeys are physically here. Everything that is not a secret and not
# darwin-specific lives in modules/home/dev.nix, which every profile imports.
#
# Absorbs the old home/common.nix + home/dev.nix pair. Those split along no
# clear line -- "common" held htop and the u2f key while "dev" held sops, and
# between them the CLI baseline was copy-pasted across four profiles so `htop`
# reached only this host. "dev" also carried a desktop package list guarded by
# `isLinux` which, since this darwin host was its only importer, never once
# evaluated; the casks below are what actually installed those apps.
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  cfg = config.machines;
  homeDir = "/Users/" + cfg.username;
in {
  imports = [
    inputs.cosmonaut.homeManagerModules.default
    inputs.scurry.homeManagerModules.default
    inputs.starla.homeManagerModules.default
  ];

  services.scurry.enable = true;

  services.starla = {
    enable = true;
    tray.enable = true;
  };

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
      "Yubico/u2f_keys" = {
        sopsFile = ../secrets/global.yaml;
        path = config.xdg.configHome + "/Yubico/u2f_keys";
      };
    };
  };

  # Fix for sops-nix LaunchAgent on macOS.
  launchd.agents.sops-nix = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      EnvironmentVariables = {
        PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  home = {
    homeDirectory = homeDir;
    inherit (cfg) username;
    stateVersion = "24.05";

    # Only what modules/home/dev.nix does not already give every host: infra
    # CLIs, a GUI editor, and the darwin-only pinentry. The shared dev tooling
    # is not repeated here.
    packages = with pkgs;
      [
        antigravity-cli
        aria2 # one-off torrent/magnet downloads: aria2c "magnet:?..."
        codex
        flyctl
        hcloud
        sops
        ssh-to-age
        vault
        zed-editor
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        pinentry_mac
      ];

    sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      SSH_ASKPASS = "/opt/homebrew/bin/ssh-askpass";
      SSH_ASKPASS_REQUIRE = "force";
    };

    # On macOS, home-manager's services.gpg-agent is unavailable (it is
    # systemd-only), so point gpg-agent at pinentry-mac directly. Needed for
    # YubiKey PIN prompts, e.g. `sops updatekeys` with the admin PGP key.
    file.".gnupg/gpg-agent.conf" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      text = ''
        pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
        default-cache-ttl 600
        max-cache-ttl 7200
      '';
    };

    file.".claude/settings.json".text = builtins.toJSON {
      includeCoAuthoredBy = false;
      permissions.defaultMode = "auto";
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
      };
      skipAutoPermissionPrompt = true;
      skipWorkflowUsageWarning = true;
    };
  };

  programs = {
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

    git = {
      # The only host with a YubiKey, so the only one that can sign.
      signing = {
        format = "ssh";
        key = "~/.ssh/yubikey_5c_nano";
        signByDefault = true;
      };
      settings = {
        credential = {
          helper = "!gh auth git-credential";
          "https://github.com".username = "ananthb";
        };
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "endeavour.local 10.15.16.123" = {
          IdentityAgent = "none";
          AddKeysToAgent = "no";
          IdentitiesOnly = "yes";
        };
        # flatcar-gateway (the CM4) has the plain discovery key in its
        # authorized_keys, so skip the YubiKey and its askpass prompt.
        # Temporary: this node is mid-conversion to its replacement, whose
        # Flatcar root authorizes only the two YubiKey keys. Drop this
        # block once that host takes over.
        "flatcar-gateway flatcar-gateway.local 10.15.16.101" = {
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = "yes";
        };
        # Exclude codespace hosts (cs.* and cs-*) so the YubiKey
        # IdentityFile doesn't block `gh codespace ssh` when the
        # device isn't plugged in. cosmonaut's doctor flags a bare
        # `Host *` here for exactly this reason. flatcar-gateway is
        # excluded for a different reason: ssh accumulates IdentityFile
        # across every matching block, so leaving it in here would put
        # the YubiKey ahead of id_ed25519 and prompt anyway.
        "* !cs-* !cs.* !flatcar-gateway !flatcar-gateway.local !10.15.16.101" = {
          IdentityFile = "~/.ssh/yubikey_5c_nano";
        };
      };
    };
  };
}
