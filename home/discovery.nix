{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.starla.homeManagerModules.default
  ];

  services.starla = {
    enable = true;
    tray.enable = true;
  };

  home = {
    packages = [
      pkgs.aria2 # one-off torrent/magnet downloads: aria2c "magnet:?..."
      pkgs.codex
    ];

    sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      SSH_ASKPASS = "/opt/homebrew/bin/ssh-askpass";
      SSH_ASKPASS_REQUIRE = "force";
    };
  };

  programs = {
    git = {
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
        # Temporary: this node is mid-conversion to pwu-compute2, whose
        # Flatcar root authorizes only the two YubiKey keys. Drop this
        # block once it boots as pwu-compute2.
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
