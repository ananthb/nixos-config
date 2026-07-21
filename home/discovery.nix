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
    packages = [pkgs.codex];

    sessionVariables = lib.mkIf pkgs.stdenv.isDarwin {
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
        # Exclude codespace hosts (cs.* and cs-*) so the YubiKey
        # IdentityFile doesn't block `gh codespace ssh` when the
        # device isn't plugged in. cosmonaut's doctor flags a bare
        # `Host *` here for exactly this reason.
        "* !cs-* !cs.*" = {
          IdentityFile = "~/.ssh/yubikey_5c_nano";
        };
      };
    };
  };
}
