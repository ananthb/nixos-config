{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.machines = {
    username = mkOption {
      type = types.str;
      default = "ananth";
      description = "Primary user account name.";
    };
  };
}
