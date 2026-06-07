# Shared Home Assistant configuration.
# Provides common components, custom integrations, HTTP/proxy settings,
# backup, and vault-secrets wiring.
#
# Hosts import this module and set:
#   my-services.hass = { name, secretsPrefix, externalUrl, internalUrl };
# Then use standard services.home-assistant.* for host-specific config.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my-services.hass;
  vs = config.vault-secrets.secrets;
  secretName = lib.replaceStrings ["/"] ["-"] cfg.secretsPrefix;
in {
  options.my-services.hass = {
    enable = lib.mkEnableOption "Home Assistant with shared KEDI defaults";

    name = lib.mkOption {
      type = lib.types.str;
      description = "Display name for this Home Assistant instance.";
    };

    secretsPrefix = lib.mkOption {
      type = lib.types.str;
      description = "Vault secrets path prefix (slashes replaced with dashes for secret name).";
    };

    externalUrl = lib.mkOption {
      type = lib.types.str;
      description = "External URL for this Home Assistant instance.";
    };

    internalUrl = lib.mkOption {
      type = lib.types.str;
      description = "Internal/LAN URL for this Home Assistant instance.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      package = pkgs.home-assistant.overrideAttrs (_: {
        doInstallCheck = false;
      });
      openFirewall = true;
      extraPackages = ps: [ps.ollama ps.speedtest-cli];
      extraComponents = [
        # baseline
        "analytics"
        "default_config"
        "dhcp"
        "google_translate"
        "met"
        "shopping_list"
        "isal"

        # home stuff
        "androidtv"
        "androidtv_remote"
        "apple_tv"
        "bluetooth"
        "bluetooth_adapters"
        "bluetooth_le_tracker"
        "camera"
        "cast"
        "ecovacs"
        "esphome"
        "mqtt"
      ];
      customComponents = with pkgs.home-assistant-custom-components; [
        ecoflow_cloud
        (frigate.overridePythonAttrs {doCheck = false;})
        miraie
        prometheus_sensor
        smartir
        spook
      ];
      config = {
        default_config = {};
        prometheus = {};

        http = {
          trusted_proxies = [
            "::1"
            "127.0.0.0/8"
          ];
          use_x_forwarded_for = true;
          ip_ban_enabled = true;
          login_attempts_threshold = 5;
        };

        homeassistant = {
          inherit (cfg) name;
          unit_system = "metric";
          time_zone = config.time.timeZone;
          latitude = "!include ${vs.${secretName}}/latitude";
          longitude = "!include ${vs.${secretName}}/longitude";
          elevation = "!include ${vs.${secretName}}/elevation";
          temperature_unit = "C";
          currency = "INR";
          country = "IN";
          external_url = cfg.externalUrl;
          internal_url = cfg.internalUrl;
        };

        smartir = {};
      };
    };

    my-services.kediTargets.home-assistant = true;

    systemd.services.home-assistant.partOf = ["kedi.target"];

    systemd.services."home-assistant-backup" = {
      startAt = "daily";
      environment.KOPIA_CHECK_FOR_UPDATES = "false";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${config.my-scripts.kopia-backup} /var/lib/hass/backups";
      };
      path = [pkgs.coreutils pkgs.curl pkgs.kopia];
    };

    vault-secrets.secrets.${secretName} = {
      services = ["home-assistant"];
      group = config.users.groups.hass.name;
    };
  };
}
