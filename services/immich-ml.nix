{containerImages, ...}: {
  virtualisation.quadlet = {
    autoUpdate.enable = true;
    containers.immich-machine-learning = {
      containerConfig = {
        name = "immich-machine-learning";
        image = containerImages.immichMl;
        autoUpdate = "registry";
        publishPorts = ["3003:3003"];
        volumes = [
          "immich-model-cache:/cache"
        ];
      };
      serviceConfig = {
        Restart = "on-failure";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [3003];

  my-services.kediTargets.immich-machine-learning = true;

  systemd.services.immich-machine-learning = {
    partOf = ["kedi.target"];
  };
}
