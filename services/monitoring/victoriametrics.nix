{
  config,
  lib,
  outputs,
  ...
}: let
  inherit
    (lib)
    mapAttrsToList
    flatten
    concatMap
    optionals
    hasAttr
    ;

  vs = config.vault-secrets.secrets;

  # Helper functions to check for enabled services/exporters
  hasService = c: name: hasAttr name c.services && c.services.${name}.enable or false;
  hasExporter = c: name:
    hasAttr "exporters" c.services.prometheus
    && c.services.prometheus.exporters.${name}.enable or false;
  exporterPort = c: name: toString c.services.prometheus.exporters.${name}.port;
  hasQuadletContainer = c: name:
    hasAttr "virtualisation" c
    && hasAttr "quadlet" c.virtualisation
    && hasAttr "containers" c.virtualisation.quadlet
    && hasAttr name c.virtualisation.quadlet.containers;

  # Check if a brew package is installed (for macOS)
  # Brews can be strings or attribute sets with a 'name' field
  hasBrew = c: pkgName:
    lib.any (x:
      (
        if builtins.isString x
        then x
        else x.name
      )
      == pkgName)
    c.homebrew.brews or [];

  # Host lists with their configs
  nixosHosts =
    mapAttrsToList (name: value: {
      inherit name;
      inherit (value) config;
    })
    outputs.nixosConfigurations;

  darwinHosts =
    mapAttrsToList (name: value: {
      inherit name;
      inherit (value) config;
    })
    outputs.darwinConfigurations;

  # --- Target Generation Logic ---

  # Helper: build target list for a prometheus exporter across all NixOS hosts.
  mkExporterTargets = name:
    concatMap (
      host:
        if hasExporter host.config name
        then ["${host.name}:${exporterPort host.config name}"]
        else []
    )
    nixosHosts;

  # 1. Node Exporter (Machine metrics)
  nodeTargets = let
    linux = mkExporterTargets "node";
    mac =
      concatMap (
        host:
          if hasBrew host.config "node_exporter"
          then ["${host.name}:9100"]
          else []
      )
      darwinHosts;
    static = [
      "framework.tail030950.ts.net:9100"
    ];
  in
    linux ++ mac ++ static;

  # 2. Blackbox Exporter (The prober itself)
  blackboxExporterTargets =
    if hasExporter config "blackbox"
    then ["${config.networking.hostName}:${exporterPort config "blackbox"}"]
    else [];

  # 3. Libvirt Exporter
  libvirtTargets = let
    dynamic = mkExporterTargets "libvirt";
    static = [
      "framework.tail030950.ts.net:9177"
    ];
  in
    dynamic ++ static;

  # 4. SmartCTL Exporter
  smartctlTargets = mkExporterTargets "smartctl";

  # 5. Speedtest Exporter
  speedtestTargets = mkExporterTargets "speedtest";

  # 6. UPS (NUT) Exporter
  nutTargets =
    concatMap (
      host:
        if hasAttr "ups" host.config.power && host.config.power.ups.enable
        then ["${host.name}:${exporterPort host.config "nut"}"]
        else []
    )
    nixosHosts;

  # 7. EcoFlow Exporter
  ecoflowTargets = mkExporterTargets "ecoflow";

  # 9. App Exporters (Radarr, Sonarr, Prowlarr, Postgres)
  appTargets = let
    getAppTargets = host: let
      c = host.config;
    in
      flatten [
        (optionals (hasExporter c "exportarr-radarr") ["${host.name}:${exporterPort c "exportarr-radarr"}"])
        (optionals (hasExporter c "exportarr-sonarr") ["${host.name}:${exporterPort c "exportarr-sonarr"}"])
        (optionals (hasExporter c "exportarr-prowlarr") ["${host.name}:${exporterPort c "exportarr-prowlarr"}"])
        (optionals (hasExporter c "postgres") ["${host.name}:${exporterPort c "postgres"}"])
      ];
  in
    concatMap getAppTargets nixosHosts;

  # 8. Starla RIPE Atlas Probe metrics
  starlaTargets =
    concatMap (
      host:
        if hasService host.config "starla" && (host.config.services.starla.metrics.enable or true)
        then let
          listenAddr = host.config.services.starla.metrics.listenAddr or "127.0.0.1:9695";
          port = lib.last (lib.splitString ":" listenAddr);
        in ["${host.name}:${port}"]
        else []
    )
    nixosHosts;

  # 9. Blackbox Ping Targets (Hosts to ping)
  # All NixOS + Darwin hosts
  pingTargets = let
    linux = map (h: h.name) nixosHosts;
    mac = map (h: h.name) darwinHosts;
    static = [
      "pikvm"
    ];
  in
    linux ++ mac ++ static;

  # 9. Blackbox HTTP Targets (Apps)
  # Use service-enabled checks to avoid hardcoding hostnames.
  blackboxHttpTargets = let
    mkHttpTarget = host: serviceName: appName: url:
      optionals (hasService host.config serviceName) [
        {
          targets = [url];
          labels = {
            type = "app";
            role = "server";
            app = appName;
          };
        }
      ];
    getTargets = host:
      flatten [
        (mkHttpTarget host "radarr" "radarr" "http://${host.name}:7878")
        (mkHttpTarget host "sonarr" "sonarr" "http://${host.name}:8989")
        (mkHttpTarget host "prowlarr" "prowlarr" "http://${host.name}:9696")
        (mkHttpTarget host "immich" "immich" "http://${host.name}:2283/auth/login")
        (mkHttpTarget host "jellyfin" "jellyfin" "http://${host.name}:8096/web/")
        (mkHttpTarget host "seerr" "seerr" "http://${host.name}:5055")
        (mkHttpTarget host "home-assistant" "home-assistant" "http://${host.name}:8123")
        (optionals (hasQuadletContainer host.config "seafile") [
          {
            targets = ["http://${host.name}:4444"];
            labels = {
              type = "app";
              role = "server";
              app = "seafile";
            };
          }
        ])
      ];
  in
    concatMap getTargets nixosHosts;

  # 10. Blackbox scrape configs (one per blackbox exporter)
  blackboxScrapes = let
    indexed = map (exporter: {inherit exporter;}) blackboxExporterTargets;
    suffixFor = item: let
      host = builtins.head (lib.splitString ":" item.exporter);
    in "-${lib.replaceStrings ["."] ["-"] host}";
  in
    concatMap (
      item: let
        inherit (item) exporter;
        suffix = suffixFor item;
        privateHttpsConfigs = [
          {
            targets = [
              "https://6a.kedi.dev"
              "https://actual.kedi.dev"
              "https://mealie.kedi.dev"
              "https://metrics.kedi.dev"
              "https://vault.kedi.dev"
            ];
            labels = {
              type = "app";
              role = "server";
            };
          }
          {
            targets = [
              "https://wallabag.kedi.dev"
            ];
            labels = {
              type = "app";
              role = "server";
              app = "news";
            };
          }
          {
            targets = [
              "https://immich.kedi.dev/auth/login"
            ];
            labels = {
              type = "app";
              role = "server";
              app = "immich";
            };
          }
          {
            targets = [
              "https://seafile.kedi.dev/accounts/login/"
            ];
            labels = {
              type = "app";
              role = "server";
              app = "seafile";
            };
          }
          {
            targets = [
              "https://tv.tail42937.ts.net/web/"
              "https://tv.kedi.dev/web/"
            ];
            labels = {
              type = "app";
              role = "server";
              app = "jellyfin";
            };
          }
        ];
      in [
        {
          job_name = "blackbox_ping${suffix}";
          metrics_path = "/probe";
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
            {
              source_labels = ["type"];
              regex = "^$";
              target_label = "type";
              replacement = "app";
              action = "replace";
            }
            {
              source_labels = ["role"];
              regex = "^$";
              target_label = "role";
              replacement = "server";
              action = "replace";
            }
            {
              target_label = "__address__";
              replacement = exporter;
            }
          ];
          params.module = ["icmp"];
          static_configs = [
            {
              targets = pingTargets;
              labels = {
                type = "node";
                os = "linux"; # Generic, though some are mac
                role = "server";
              };
            }
            {
              targets = [
                "atlantis"
                "ds9"
                "intrepid"
              ];
              labels = {
                type = "node";
                os = "openwrt";
                role = "router";
              };
            }
            {
              targets = [
                "2001:4860:4860::8888"
                "2001:4860:4860::8844"
                "2606:4700:4700::1001"
                "2606:4700:4700::1111"
                "8.8.8.8"
                "8.8.4.4"
                "1.1.1.1"
                "1.0.0.1"
              ];
              labels = {
                role = "canary";
                type = "internet-dns";
              };
            }
          ];
        }
        {
          job_name = "blackbox_http_2xx${suffix}";
          metrics_path = "/probe";
          params.module = ["http_2xx"];
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
            {
              source_labels = [
                "app"
                "__param_target"
              ];
              regex = ";https?://([^.]+).*";
              target_label = "app";
              replacement = "$1";
              action = "replace";
            }
            {
              source_labels = [
                "app"
                "__param_target"
              ];
              regex = ";([^.:/]+).*";
              target_label = "app";
              replacement = "$1";
              action = "replace";
            }
            {
              source_labels = ["type"];
              regex = "^$";
              target_label = "type";
              replacement = "app";
              action = "replace";
            }
            {
              source_labels = ["role"];
              regex = "^$";
              target_label = "role";
              replacement = "server";
              action = "replace";
            }
            {
              target_label = "__address__";
              replacement = exporter;
            }
          ];
          static_configs =
            # Generated per-host based on enabled services.
            blackboxHttpTargets
            ++ [
              {
                targets = [
                  "http://atlantis"
                  "http://ds9"
                  "http://intrepid"
                ];
                labels = {
                  os = "openwrt";
                  type = "node";
                  role = "router";
                };
              }
            ];
        }
        {
          job_name = "blackbox_https_2xx${suffix}";
          metrics_path = "/probe";
          params.module = ["https_2xx"];
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = exporter;
            }
          ];
          static_configs =
            [
              {
                targets = [
                  "https://bhaskararaman.com"
                  "https://private.tech"
                  "https://coredump.blog"
                  "https://lilaartscentre.com"
                  "https://shakthipalace.com"
                ];
                labels.type = "internet-host";
                labels.role = "server";
              }
              {
                targets = [
                  "https://www.google.com"
                  "https://www.cloudflare.com"
                ];
                labels.type = "internet-host";
                labels.role = "canary";
              }
            ]
            ++ privateHttpsConfigs;
        }
      ]
    )
    indexed;
in {
  environment.systemPackages = [config.services.victoriametrics.package];

  services.victoriametrics = {
    enable = true;
    retentionPeriod = "180d";
    extraOptions = [
      "-enableTCP6"
    ];
    prometheusConfig = {
      global.scrape_interval = "10s";

      /**
      Label definitions:

      1. type: node|app|exporter|internet-dns|internet-host
      2. role: server|router|canary|ups
      */

      scrape_configs =
        [
          {
            job_name = "blackbox_exporter";
            static_configs = [
              {
                targets = blackboxExporterTargets;
                labels.type = "exporter";
              }
            ];
          }
        ]
        ++ blackboxScrapes
        ++ [
          {
            job_name = "network";
            static_configs = [
              {
                targets = [
                  "atlantis:9100"
                  "ds9:9100"
                  "intrepid:9100"
                ];
                labels = {
                  os = "openwrt";
                  type = "exporter";
                  role = "router";
                };
              }
            ];
          }
          {
            job_name = "machines";
            static_configs = [
              {
                targets = nodeTargets;
                labels = {
                  type = "exporter";
                  role = "server";
                };
              }
            ];
          }
          {
            job_name = "apps";
            relabel_configs = [
              {
                source_labels = ["__address__"];
                regex = ".*:9708$";
                target_label = "app";
                replacement = "radarr";
                action = "replace";
              }
              {
                source_labels = ["__address__"];
                regex = ".*:9709$";
                target_label = "app";
                replacement = "sonarr";
                action = "replace";
              }
              {
                source_labels = ["__address__"];
                regex = ".*:9710$";
                target_label = "app";
                replacement = "prowlarr";
                action = "replace";
              }
              {
                source_labels = ["__address__"];
                regex = ".*:8096$";
                target_label = "app";
                replacement = "jellyfin";
                action = "replace";
              }
              {
                source_labels = ["__address__"];
                regex = ".*:8081$";
                target_label = "app";
                replacement = "immich";
                action = "replace";
              }
              {
                source_labels = ["__address__"];
                regex = ".*:8082$";
                target_label = "app";
                replacement = "immich";
                action = "replace";
              }
            ];
            static_configs = [
              {
                targets = appTargets;
                labels.type = "exporter";
                labels.role = "server";
              }
              {
                targets = smartctlTargets;
                labels.type = "exporter";
                labels.role = "disks";
              }
              {
                targets = nutTargets;
                labels.type = "exporter";
                labels.role = "ups";
              }
            ];
          }
          {
            job_name = "nut";
            metrics_path = "/ups_metrics";
            static_configs = [
              {
                targets = nutTargets;
                labels.type = "exporter";
                labels.role = "ups";
              }
            ];
          }
          {
            job_name = "speedtest";
            static_configs = [
              {
                targets = speedtestTargets;
                labels.type = "exporter";
                labels.role = "internet";
              }
            ];
          }
          {
            job_name = "ecoflow";
            static_configs = [
              {
                targets = ecoflowTargets;
                labels.type = "exporter";
                labels.role = "ups";
              }
            ];
          }
          {
            job_name = "libvirt";
            static_configs = [
              {
                targets = libvirtTargets;
                labels.type = "exporter";
                labels.role = "hypervisor";
              }
            ];
          }
          {
            job_name = "starla";
            static_configs = [
              {
                targets = starlaTargets;
                labels.type = "app";
                labels.app = "starla";
              }
            ];
          }
          {
            job_name = "wan_billing";
            metrics_path = "/metrics-wan-billing";
            scheme = "https";
            static_configs = [
              {
                targets = ["atlantis.tail42937.ts.net"];
                labels = {
                  type = "exporter";
                  role = "router";
                  os = "openwrt";
                };
              }
            ];
          }
          {
            job_name = "home_assistant_6a";
            metrics_path = "/api/prometheus";
            scheme = "https";
            authorization = {
              type = "Bearer";
              credentials_file = "${vs.home-assistant-6a-vm}/access_token";
            };
            static_configs = [
              {
                targets = ["6a.kedi.dev"];
                labels.type = "app";
                labels.app = "home-assistant";
              }
            ];
          }
          {
            job_name = "home_assistant_t1";
            metrics_path = "/api/prometheus";
            scheme = "https";
            authorization = {
              type = "Bearer";
              credentials_file = "${vs.home-assistant-t1-vm}/access_token";
            };
            static_configs = [
              {
                targets = ["t1.kedi.dev"];
                labels.type = "app";
                labels.app = "home-assistant";
              }
            ];
          }
        ];
    };
  };

  systemd.services = {
    victoriametrics = {
      serviceConfig.ReadOnlyPaths = lib.concatStringsSep " " [
        "${vs.home-assistant-6a-vm}/access_token"
        "${vs.home-assistant-t1-vm}/access_token"
      ];
      serviceConfig.SupplementaryGroups = ["hass"];
      after = [
        "sops-install-secrets.service"
        "home-assistant-6a-vm-secrets.service"
        "home-assistant-t1-vm-secrets.service"
      ];
      requires = [
        "sops-install-secrets.service"
        "home-assistant-6a-vm-secrets.service"
        "home-assistant-t1-vm-secrets.service"
      ];
    };
    "home-assistant-6a-vm-secrets".serviceConfig.UMask = "0027";
    "home-assistant-t1-vm-secrets".serviceConfig.UMask = "0027";
  };

  users.groups.hass = {};

  vault-secrets = {
    secrets = {
      home-assistant-6a-vm = {
        services = ["victoriametrics"];
        group = "hass";
      };
      home-assistant-t1-vm = {
        services = ["victoriametrics"];
        group = "hass";
      };
    };
  };
}
