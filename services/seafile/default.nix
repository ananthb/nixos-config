/**
Seafile deployment using Podman containers managed by nix-quadlet.

Components:
- Seafile server
- Notification server
- Metadata server
- Thumbnail server
- AI server
- Seadoc server
- Collabora CODE (can be hosted separately)

Dependencies:
- MySQL (MariaDB)
- Redis
- Caddy (ingress) - listening on port 4444 on all interfaces

Configuration files and secrets are managed using vault-secrets.
*/
{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../caddy.nix
    ./containers.nix
  ];

  users.groups.seafile = {};

  services = {
    caddy = {
      enable = true;
      virtualHosts.":4444".extraConfig = ''
        # seafile
        reverse_proxy http://localhost:4450

        # notification server
        handle_path /notification* {
          reverse_proxy http://localhost:8083
        }

        # thumbnail server
        handle /thumbnail/* {
          reverse_proxy http://localhost:4453

        }
        handle_path /thumbnail/ping {
          rewrite /ping
          reverse_proxy http://localhost:4453
        }

        # seadoc
        reverse_proxy /socket.io/* http://localhost:4451
        handle_path /sdoc-server/* {
          reverse_proxy http://localhost:4451
        }

        # collabora code
        reverse_proxy /collabora-code/* http://localhost:9980
      '';
    };

    mysql = {
      enable = true;
      package = pkgs.mariadb;
      settings = {
        client.default-character-set = "utf8mb4";
        mysqld = {
          skip-name-resolve = 1;
          bind-address = "*";
          character-set-server = "utf8mb4";
          collation-server = "utf8mb4_bin";
        };
      };
      ensureUsers = [
        {
          name = "seafile";
          ensurePermissions = {
            "ccnet_db.*" = "ALL PRIVILEGES";
            "sdoc_db.*" = "ALL PRIVILEGES";
            "seafile_db.*" = "ALL PRIVILEGES";
            "seahub_db.*" = "ALL PRIVILEGES";
          };
        }
      ];
      ensureDatabases = ["ccnet_db" "sdoc_db" "seafile_db" "seahub_db"];
    };

    redis.servers.seafile = {
      enable = true;
      bind = "0.0.0.0";
      port = 6400;
      unixSocket = null;
      settings.protected-mode = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [4000];

  # Seafile access to services running on the host
  networking.firewall.interfaces.podman-seafile.allowedTCPPorts = [
    3306 # mysql
    6400 # redis-seafile
  ];

  systemd.services = {
    "redis-seafile" = {
      after = ["seafile-network.service"];
      wants = ["seafile-network.service"];
      partOf = ["kedi.target"];
      unitConfig.RequiresMountsFor = "/srv";
    };
    "seafile-mysql-backup" = {
      startAt = "hourly";
      unitConfig.RequiresMountsFor = "/srv";
      script = ''
        if ! ${pkgs.systemd}/bin/systemctl is-active seafile.service; then
          exit 0
        fi

        backup_dir="/srv/seafile/backups"
        mkdir -p "$backup_dir"

        # Removes all but 2 files starting from the oldest
        pushd "$backup_dir"
        ls -t | tail -n +3 | tr '\n' '\0' | xargs -0 rm --
        popd

        dump_file="$backup_dir/seafile_dbs_dump-$(date --utc --iso-8601=seconds).sql"
        ${pkgs.mariadb}/bin/mysqldump \
          --databases ccnet_db sdoc_db seafile_db seahub_db | \
            ${pkgs.zstd}/bin/zstd > "$dump_file.zst"
      '';
    };
    "seafile-backup" = {
      # TODO: re-enable after we've trimmed down unnecessary files
      #startAt = "weekly";
      environment.KOPIA_CHECK_FOR_UPDATES = "false";
      unitConfig.RequiresMountsFor = "/srv";
      script = ''
        ${pkgs.systemd}/bin/systemctl start seafile-mysql-backup.service
        ${config.my-scripts.kopia-snapshot-backup} /srv/seafile
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [pkgs.bcachefs-tools pkgs.btrfs-progs pkgs.coreutils pkgs.curl pkgs.kopia];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/seafile 0755 root root -"
  ];

  vault-secrets.secrets.seafile = {
    services = [
      "seafile"
      "seafile-notification-server"
      "seafile-md-server"
      "seafile-thumbnail-server"
      "seafile-ai"
      "seadoc"
    ];
    group = config.users.groups.seafile.name;
  };

  vault-secrets.secrets.collabora = {
    services = ["collabora-code"];
    group = config.users.groups.seafile.name;
  };
}
