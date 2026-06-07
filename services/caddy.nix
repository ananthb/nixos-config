_: {
  services.caddy = {
    enable = true;
    globalConfig = ''
      servers {
        trusted_proxies static ::1 127.0.0.0/8
      }
    '';
  };

  my-services.kediTargets.caddy = true;

  systemd.services.caddy = {
    partOf = ["kedi.target"];
  };
}
