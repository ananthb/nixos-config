{pkgs, ...}: {
  services.prometheus.exporters = {
    blackbox = {
      enable = true;
      configFile = pkgs.writeText "blackbox_exporter.conf" ''
        modules:
          icmp:
            prober: icmp
          http_2xx:
            prober: http
            http:
              method: GET
              no_follow_redirects: false
              fail_if_ssl: true
          https_2xx:
            prober: http
            http:
              method: GET
              no_follow_redirects: false
              fail_if_not_ssl: true
      '';
    };
  };
}
