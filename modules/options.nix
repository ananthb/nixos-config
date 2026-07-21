{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.machines = {
    username = mkOption {
      type = types.str;
      default = "ananth";
      description = "Primary user account name.";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = import ../lib/ssh-keys.nix;
      description = "SSH public keys for the primary user.";
    };
  };
}
