{
  config,
  inputs,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
  # UID of the provisioned VictoriaMetrics datasource (must match definition below).
  datasourceUid = "P3D437DB70E32EE8A";

  # Helper to build a Grafana alert rule with less boilerplate.
  mkAlert = {
    uid,
    title,
    expr,
    threshold ? 1,
    thresholdType ? "lt",
    duration ? "1m",
    keepFiring ? null,
    noData ? "NoData",
    muteAtNight ? false,
    summary,
    description ? "{{ $labels.instance }}",
  }:
    {
      inherit uid title;
      condition = "C";
      data = [
        {
          refId = "A";
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          inherit datasourceUid;
          model = {
            editorMode = "builder";
            inherit expr;
            instant = true;
            intervalMs = 1000;
            legendFormat = "__auto";
            maxDataPoints = 43200;
            range = false;
            refId = "A";
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            conditions = [
              {
                evaluator = {
                  params = [threshold];
                  type = thresholdType;
                };
                operator.type = "and";
                query.params = ["C"];
                reducer = {
                  params = [];
                  type = "last";
                };
                type = "query";
              }
            ];
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
            expression = "A";
            intervalMs = 1000;
            maxDataPoints = 43200;
            refId = "C";
            type = "threshold";
          };
        }
      ];
      noDataState = noData;
      execErrState = "Error";
      for = duration;
      isPaused = false;
      annotations = {
        inherit summary description;
      };
      notification_settings =
        {
          receiver = "grafana-default-discord";
        }
        // (
          if muteAtNight
          then {mute_time_intervals = ["Indian Nights"];}
          else {}
        );
    }
    // (
      if keepFiring != null
      then {keepFiringFor = keepFiring;}
      else {}
    );
in {
  imports = [
    ./postgres.nix
  ];

  services = {
    grafana = {
      enable = true;
      declarativePlugins = with pkgs.grafanaPlugins; [];
      settings = {
        database = {
          type = "postgres";
          host = "/run/postgresql";
          name = "grafana";
          user = "grafana";
        };

        server = {
          http_addr = "::";
          domain = "metrics.kedi.dev";
          root_url = "https://metrics.kedi.dev";
        };

        users = {
          allow_sign_up = false;
        };

        "auth.basic" = {
          enabled = false;
        };

        auth = {
          disable_login_form = true;
        };

        "auth.google" = {
          enabled = true;
          client_id = "$__file{${vs.grafana}/oauth_client_id}";
          client_secret = "$__file{${vs.grafana}/oauth_client_secret}";
          allow_sign_up = false;
          auto_login = true;
          skip_org_role_sync = true;
          scopes = "openid email profile";
        };

        security = {
          secret_key = "$__file{${vs.grafana}/secret_key}";
        };
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            url = "http://localhost:8428";
            name = "VictoriaMetrics";
            type = "prometheus";
            uid = datasourceUid;
            jsonData = {
              httpMethod = "POST";
              manageAlerts = true;
            };
          }
        ];
        dashboards.settings.providers = [
          {
            name = "applications";
            orgId = 1;
            folder = "Applications";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "${./grafana/dashboards/Applications}";
            };
          }
          {
            name = "infrastructure";
            orgId = 1;
            folder = "Infrastructure";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "${./grafana/dashboards/Infrastructure}";
            };
          }
          {
            name = "starla";
            orgId = 1;
            folder = "Applications";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "${inputs.starla}/grafana";
            };
          }
        ];
        alerting = {
          muteTimings.settings = {
            apiVersion = 1;
            muteTimes = [
              {
                orgId = 1;
                name = "Indian Nights";
                time_intervals = [
                  {
                    times = [
                      {
                        start_time = "00:00";
                        end_time = "06:00";
                      }
                    ];
                    location = "Asia/Calcutta";
                  }
                ];
              }
            ];
          };
          rules.settings = {
            apiVersion = 1;
            groups = [
              {
                orgId = 1;
                name = "Right About Now";
                folder = "Applications";
                interval = "30s";
                rules = [
                  (mkAlert {
                    uid = "dex9yo4k0n6dcb";
                    title = "Application Down";
                    expr = ''(probe_success{type="app"} or up{type="app", job!~"blackbox_.*"} or up{job="apps", role="server"})'';
                    keepFiring = "1m";
                    muteAtNight = true;
                    summary = ''{{ if $labels.app }}{{ $labels.app }}{{ else }}{{ $labels.instance }}{{ end }} is down (seen from {{ reReplaceAll `blackbox_.*-` `` $labels.job }})'';
                  })
                  (mkAlert {
                    uid = "aex9ssl4k0n6dca";
                    title = "SSL Certificate Expiring";
                    expr = ''(probe_ssl_earliest_cert_expiry - time()) / 86400'';
                    threshold = 7;
                    duration = "1h";
                    muteAtNight = true;
                    summary = "SSL cert for {{ $labels.instance }} expires in {{ $value }} days";
                  })
                ];
              }
              {
                orgId = 1;
                name = "Right About Now";
                folder = "Infrastructure";
                interval = "30s";
                rules = [
                  (mkAlert {
                    uid = "fexk4g07p6134a";
                    title = "Home Network Down";
                    expr = ''up{role=~"router|server", type="node"}'';
                    summary = "{{ $labels.instance }} is unreachable";
                  })
                  (mkAlert {
                    uid = "ff9dwibe8wqv4a";
                    title = "NUT UPS AC Power Outage";
                    expr = "network_ups_tools_input_voltage";
                    threshold = 200;
                    duration = "30s";
                    summary = "AC power lost on UPS {{ $labels.instance }}";
                  })
                  (mkAlert {
                    uid = "cf9dwz9m0fkzka";
                    title = "EcoFlow Battery AC Power Outage";
                    expr = "ecoflow_inv_ac_in_vol";
                    threshold = 200000;
                    duration = "30s";
                    summary = "AC power lost on EcoFlow {{ $labels.instance }}";
                  })
                  (mkAlert {
                    uid = "gex1disk0n6dcf";
                    title = "Disk Space Critical";
                    expr = ''node_filesystem_avail_bytes{mountpoint=~"/|/srv"} / node_filesystem_size_bytes * 100'';
                    threshold = 10;
                    duration = "5m";
                    summary = "{{ $labels.instance }} {{ $labels.mountpoint }} has {{ $value | printf \"%.0f\" }}% free";
                  })
                  (mkAlert {
                    uid = "hex2mem0n6dcg";
                    title = "High Memory Pressure";
                    expr = ''node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100'';
                    threshold = 10;
                    duration = "5m";
                    muteAtNight = true;
                    summary = "{{ $labels.instance }} has {{ $value | printf \"%.0f\" }}% memory available";
                  })
                  (mkAlert {
                    uid = "iex3sysd0n6dch";
                    title = "Systemd Service Failed";
                    expr = ''node_systemd_unit_state{state="failed"}'';
                    threshold = 1;
                    thresholdType = "gt";
                    duration = "2m";
                    muteAtNight = true;
                    summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
                  })
                  (mkAlert {
                    uid = "jex4bkup0n6dci";
                    title = "Backup Stale";
                    expr = ''(time() - kopia_backups_total) / 3600'';
                    threshold = 48;
                    thresholdType = "gt";
                    duration = "1h";
                    noData = "OK";
                    muteAtNight = true;
                    summary = "No backup for {{ $labels.instance }} in {{ $value | printf \"%.0f\" }}h";
                  })
                  (mkAlert {
                    uid = "jex4bkup1stuck0n6";
                    title = "Backup Stuck";
                    expr = ''max by (instance) (kopia_backups_count{job="hathi-backups"})'';
                    threshold = 0;
                    thresholdType = "gt";
                    duration = "6h";
                    noData = "OK";
                    summary = "Backup for {{ $labels.instance }} has been running >6h";
                  })
                  (mkAlert {
                    uid = "kex5inet0n6dcj";
                    title = "Internet Connectivity Lost";
                    expr = ''avg by (job) (probe_success{type="internet-dns"})'';
                    duration = "2m";
                    summary = "Internet down (seen from {{ reReplaceAll `blackbox_.*-` `` $labels.job }})";
                  })
                  (mkAlert {
                    uid = "lex6wan50pct0n6dci";
                    title = "WAN Monthly Usage 50%";
                    expr = ''wan_billing_month_rx_bytes / 1e12'';
                    threshold = 2.5;
                    thresholdType = "gt";
                    duration = "10m";
                    muteAtNight = true;
                    summary = "WAN download at {{ $value | printf \"%.2f\" }} TB this month (>50% of 5 TB cap)";
                  })
                  (mkAlert {
                    uid = "lex6wan75pct0n6dcj";
                    title = "WAN Monthly Usage 75%";
                    expr = ''wan_billing_month_rx_bytes / 1e12'';
                    threshold = 3.75;
                    thresholdType = "gt";
                    duration = "10m";
                    muteAtNight = true;
                    summary = "WAN download at {{ $value | printf \"%.2f\" }} TB this month (>75% of 5 TB cap)";
                  })
                  (mkAlert {
                    uid = "lex6wan80pct0n6dck";
                    title = "WAN Monthly Usage 80%";
                    expr = ''wan_billing_month_rx_bytes / 1e12'';
                    threshold = 4.0;
                    thresholdType = "gt";
                    duration = "10m";
                    muteAtNight = true;
                    summary = "WAN download at {{ $value | printf \"%.2f\" }} TB this month (>80% of 5 TB cap)";
                  })
                  (mkAlert {
                    uid = "lex6wan95pct0n6dcl";
                    title = "WAN Monthly Usage 95%";
                    expr = ''wan_billing_month_rx_bytes / 1e12'';
                    threshold = 4.75;
                    thresholdType = "gt";
                    duration = "5m";
                    summary = "WAN download at {{ $value | printf \"%.2f\" }} TB this month (>95% of 5 TB cap)";
                  })
                  (mkAlert {
                    uid = "lex6wanstale0n6dcm";
                    title = "WAN Billing Counter Stale";
                    expr = ''time() - wan_billing_last_update_timestamp_seconds'';
                    threshold = 600;
                    thresholdType = "gt";
                    duration = "10m";
                    noData = "OK";
                    muteAtNight = true;
                    summary = "wan-billing.sh on atlantis hasn't updated in {{ $value | printf \"%.0f\" }}s — monthly cap tracking is blind";
                  })
                ];
              }
            ];
          };
          policies.settings = {
            apiVersion = 1;
            resetPolicies = [1];
            policies = [
              {
                orgId = 1;
                receiver = "grafana-default-discord";
                group_by = [
                  "grafana_folder"
                  "alertname"
                ];
                group_wait = "5m";
                group_interval = "5m";
                repeat_interval = "4h";
              }
            ];
          };
          contactPoints.path = "${vs.grafana}/contactpoints.yaml";
        };
      };
    };

    postgresql = {
      enable = true;
      ensureDatabases = ["grafana"];
      ensureUsers = [
        {
          name = "grafana";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [3000];

  vault-secrets.secrets.grafana = {
    services = ["grafana"];
    group = config.users.groups.grafana.name;
  };
}
