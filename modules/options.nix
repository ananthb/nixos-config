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
      default = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINu7u4V6khhhUvepvptel86DN3XMCwZVdQe/7P6WW1KmAAAAFXNzaDphbmFudGhzLXNzaC1rZXktMQ== ananth@yubikey-5c"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIFCVZPWg3DVxjuORNKJnjaRSPoZ4nYnzM070q0fIeM32AAAAG3NzaDphbmFudGhzLXNzaC1rZXktNWMtbmFubw== ananth@yubikey-5c-nano"
      ];
      description = "SSH public keys for the primary user.";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Asia/Kolkata";
      description = "System timezone.";
    };

    locale = mkOption {
      type = types.str;
      default = "en_IN.UTF-8";
      description = "System default locale.";
    };

    vault = {
      address = mkOption {
        type = types.str;
        default = "http://endeavour:8200";
        description = "Vault server address.";
      };
    };

    monitoring = {
      vmHost = mkOption {
        type = types.nullOr types.str;
        default = "endeavour";
        description = "Host running VictoriaMetrics. Null to auto-detect or disable.";
      };
    };

    serviceTarget = {
      name = mkOption {
        type = types.str;
        default = "kedi";
        description = "Name of the systemd target that groups managed services.";
      };
    };
  };
}
