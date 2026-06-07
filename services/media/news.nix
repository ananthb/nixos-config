{
  config,
  containerImages,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  imports = [
    ../monitoring/postgres.nix
  ];

  systemd.services = {
    wallabag = {
      partOf = ["kedi.target"];
      serviceConfig.SupplementaryGroups = ["news"];
    };
    wallabag-secrets.serviceConfig.UMask = "0027";
  };

  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) volumes;
  in {
    autoEscape = true;
    autoUpdate.enable = true;

    volumes = {
      wallabag-data = {};
      wallabag-images = {};
    };

    containers.wallabag.containerConfig = {
      name = "wallabag";
      image = containerImages.wallabag;
      autoUpdate = "registry";
      volumes = [
        "${volumes.wallabag-data.ref}:/var/www/wallabag/data"
        "${volumes.wallabag-images.ref}:/var/www/wallabag/web/assets/images"
      ];
      publishPorts = ["8085:80"];
      environmentFiles = ["${vs.wallabag}/environment"];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      8085 # wallabag
    ];
    interfaces.podman0.allowedTCPPorts = [
      5432 # postgres
    ];
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    authentication = ''
      host wallabag wallabag 10.0.0.0/8 md5
    '';
    ensureDatabases = [
      "wallabag"
    ];
    ensureUsers = [
      {
        name = "wallabag";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };

  vault-secrets.secrets.wallabag = {
    services = ["wallabag"];
    group = "news";
  };

  users.groups.news = {};

  my-services.kediTargets.wallabag = true;
}
