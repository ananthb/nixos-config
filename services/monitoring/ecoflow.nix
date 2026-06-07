{
  config,
  lib,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  users.groups."prometheus-ecoflow-exporter" =
    lib.mkIf config.services.prometheus.exporters.ecoflow.enable
    (lib.mkDefault {});

  services.prometheus.exporters.ecoflow = {
    enable = true;
    exporterType = "mqtt";
    ecoflowEmailFile = "${vs.ecoflow}/email";
    ecoflowPasswordFile = "${vs.ecoflow}/password";
    ecoflowDevicesPrettyNamesFile = "${vs.ecoflow}/devices_pretty_names";
  };

  systemd.services.prometheus-ecoflow-exporter = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig.SupplementaryGroups = ["prometheus-ecoflow-exporter"];
  };

  vault-secrets.secrets.ecoflow = {
    services = ["prometheus-ecoflow-exporter"];
    group = "prometheus-ecoflow-exporter";
  };
}
