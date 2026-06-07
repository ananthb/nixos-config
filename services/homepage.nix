{config, ...}: let
  vs = config.vault-secrets.secrets;
in {
  users.groups."homepage-secrets" = {};

  services.homepage-dashboard = {
    enable = true;
    listenPort = 8802;
    allowedHosts = "kedi.dev";
    settings = {
      title = "KEDI";
      description = "Self-hosted apps for the people";
      base = "https://kedi.dev";
      target = "_blank";
    };
    environmentFiles = ["${vs.homepage}/environment"];
  };

  vault-secrets.secrets.homepage = {
    services = ["homepage-dashboard"];
    group = "homepage-secrets";
  };

  my-services.kediTargets.homepage-dashboard = true;

  systemd.services.homepage-dashboard = {
    partOf = ["kedi.target"];
    serviceConfig.SupplementaryGroups = ["homepage-secrets"];
  };

  systemd.services.homepage-secrets.serviceConfig.UMask = "0027";
}
