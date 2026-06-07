{
  containerImages,
  inputs,
  ...
}: {
  imports = [
    inputs.starla.nixosModules.default
  ];

  # Starla RIPE Atlas probe (replaces ripe-atlas-probe container)
  services.starla = {
    enable = true;
    reportInterfaceStats = true;
    metrics.listenAddr = "[::]:9695";
  };

  virtualisation.quadlet = {
    containers = {
      globalping-probe.containerConfig = {
        name = "globalping-probe";
        image = containerImages.globalpingProbe;
        autoUpdate = "registry";
        networks = ["host"];
        addCapabilities = ["NET_RAW"];
      };
    };
  };
}
