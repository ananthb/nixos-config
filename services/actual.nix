{
  config,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  services.actual = {
    enable = true;
    settings.port = 3001;
  };

  my-services.kediTargets.actual = true;

  systemd.services = {
    actual = {
      serviceConfig.EnvironmentFile = "${vs.actual}/environment";
      environment = {
        ACTUAL_OPENID_DISCOVERY_URL = "https://accounts.google.com/.well-known/openid-configuration";
        ACTUAL_OPENID_SERVER_HOSTNAME = "https://actual.kedi.dev";
      };
      partOf = ["kedi.target"];
    };

    "actual-backup" = config.my-services.mkBackupService {
      stopService = "actual";
      extraPath = [pkgs.systemd];
      script = ''
        backup_target="/var/lib/actual"
        snapshot_target="$(${pkgs.mktemp}/bin/mktemp -d)"
        trap '{ rm -rf "$snapshot_target"; }' EXIT
        ${pkgs.rsync}/bin/rsync -avz "$backup_target/" "$snapshot_target"
        ${config.my-scripts.kopia-backup} "$snapshot_target" "$backup_target"
      '';
    };
  };

  vault-secrets.secrets.actual = {
    services = ["actual"];
  };
}
