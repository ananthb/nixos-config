{
  config,
  lib,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  users.users.mealie = {
    isSystemUser = true;
    group = "mealie";
  };
  users.groups.mealie = {};

  services.mealie = {
    enable = true;
    listenAddress = "[::1]";
    credentialsFile = "${vs.mealie}/environment";
  };

  my-services.kediTargets.mealie = true;

  # Fix ownership of state directory after switching from DynamicUser to static user.
  systemd = {
    tmpfiles.rules = [
      "Z /var/lib/mealie - mealie mealie - -"
    ];

    services.mealie = {
      partOf = ["kedi.target"];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        SupplementaryGroups = ["mealie"];
      };
    };

    services."mealie-backup" = config.my-services.mkBackupService {
      startAt = "weekly";
      extraServiceConfig.EnvironmentFile = "${vs.mealie}/environment";
      script = ''
        set -uo pipefail

        backup_api_url="http://localhost:9000/api/admin/backups"

        http() {
          ${pkgs.httpie}/bin/http -A bearer -a "$MEALIE_BACKUP_API_KEY" \
            --check-status \
            --ignore-stdin \
            --timeout=10 \
            "$@"
        }

        # Delete all backups
        http GET "$backup_api_url" \
          | ${pkgs.jq}/bin/jq -r '.imports[].name' \
          | ${pkgs.findutils}/bin/xargs -I{} \
            ${pkgs.httpie}/bin/http -A bearer -a "$MEALIE_BACKUP_API_KEY" \
              --check-status \
              --ignore-stdin \
              --timeout=10 \
              DELETE "$backup_api_url/"{}

        # Create new backup
        http POST "$backup_api_url"

        # Upload new backup
        ${config.my-scripts.kopia-backup} /var/lib/mealie/backups
      '';
    };
  };

  vault-secrets.secrets.mealie = {
    services = [
      "mealie"
      "mealie-backup"
    ];
    group = "mealie";
  };
}
