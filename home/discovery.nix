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

  # The keys nix insists on in ~/.claude/settings.json. Anything NOT listed
  # here is Claude's to write and is preserved across rebuilds; anything that
  # is listed is restored on every switch, so change these here rather than in
  # /config. autoMode.environment is context handed to the auto-mode
  # classifier -- "$defaults" keeps the built-in entries and appends ours.
  claudeSettings = {
    includeCoAuthoredBy = false;
    skipAutoPermissionPrompt = true;
    skipWorkflowUsageWarning = true;
    permissions.defaultMode = "auto";
    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
    };
    autoMode.environment = [
      "$defaults"
      "This is the user's personal Mac (hostname: discovery). ~/src/nixos-config is the nix-darwin + home-manager config for all of their hosts; applying it means `sudo darwin-rebuild switch --flake .#discovery`, which is routine here and is expected to require sudo."
      "Homebrew packages on this machine are declared in that repo, with homebrew.onActivation.cleanup = \"zap\". A manual `brew install` does not survive the next rebuild, and removing a cask from the nix lists uninstalls the app and deletes its ~/Library data."
      "Git commits here are signed with a YubiKey and block on a physical touch with no on-screen prompt, so a commit can look like it has hung when it is only waiting."
    ];
  };

  claudeSettingsFile =
    pkgs.writeText "claude-settings.json" (builtins.toJSON claudeSettings);
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
        aria2 # one-off torrent/magnet downloads: aria2c "magnet:?..."
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

    # ~/.claude/settings.json cannot be a home.file. That writes a symlink
    # into the store, which is read-only, and Claude Code writes this file
    # itself -- "always allow" on a permission prompt, /config toggles, the
    # auto-mode opt-in all land here and would silently fail. So rather than
    # owning the file, merge the declared keys into whatever is already there
    # and leave the rest untouched: jq's `*` is a recursive merge with the
    # right side winning, so claudeSettings overrides key by key instead of
    # replacing the document. Arrays are replaced whole, which is what
    # autoMode.environment wants.
    #
    # Bad JSON in the existing file is left alone rather than overwritten --
    # it is more likely a half-written edit worth keeping than garbage.
    # The `run` wrapper cannot be used below: it becomes `echo` under
    # --dry-run, and a redirect attached to it would still truncate the
    # target and fill it with the echoed command. Guard the whole block on
    # DRY_RUN instead, the way home-manager's own modules do.
    activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings="${homeDir}/.claude/settings.json"

      if [[ -v DRY_RUN ]]; then
        echo "would merge ${claudeSettingsFile} into $settings"
      else
        mkdir -p "$(dirname "$settings")"

        if [ ! -s "$settings" ]; then
          install -m 644 ${claudeSettingsFile} "$settings"
        elif ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$settings" ${claudeSettingsFile} \
            >"$settings.hm-merged" \
            && mv -f "$settings.hm-merged" "$settings"
          chmod 644 "$settings"
        else
          warnEcho "$settings is not valid JSON; leaving it alone."
        fi
      fi
    '';
  };

  programs = {
    cosmonaut = {
      enable = true;
      # Coder workspaces only — the github provider would otherwise nag
      # about codespace auth just because gh is installed for git.
      workspaceProvider = "coder";
      providers.github.enable = false;
      # Remote shells attach to a persistent zellij session that
      # survives SSH drops.
      ssh.multiplexer = "zellij";
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
