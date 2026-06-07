_: {
  services.prometheus.exporters.postgres = {
    enable = true;
    runAsLocalSuperUser = true;
    openFirewall = true;
  };
}
