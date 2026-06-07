{
  config,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  imports = [
    ./monitoring/postgres.nix
  ];

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    config = {
      DATABASE_URL = "postgresql://vaultwarden@/vaultwarden?host=/run/postgresql";

      ROCKET_ADDRESS = "::";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";

      # sign ups
      INVITATIONS_ALLOWED = true;
      SIGNUPS_ALLOWED = false;

      DOMAIN = "https://vaultwarden.kedi.dev";
      PUSH_ENABLED = true;
      PUSH_IDENTITY_URI = "https://identity.bitwarden.eu";
      PUSH_RELAY_URI = "https://api.bitwarden.eu";
      SMTP_FROM = "vault@kedi.dev";
      SMTP_FROM_NAME = "KEDI Vaultwarden";
    };
    environmentFile = "${vs.vaultwarden}/environment";
  };

  my-services.kediTargets.vaultwarden = true;

  systemd.services.vaultwarden = {
    partOf = ["kedi.target"];
  };

  systemd.services."vaultwarden-backup" = config.my-services.mkBackupService {
    stopService = "vaultwarden";
    extraPath = [pkgs.systemd];
    script = ''
      backup_target="/var/lib/${config.systemd.services.vaultwarden.serviceConfig.StateDirectory}"
      snapshot_target="$(${pkgs.mktemp}/bin/mktemp -d)"
      trap '{ rm -rf "$snapshot_target"; }' EXIT
      ${pkgs.sudo}/bin/sudo -u vaultwarden \
        ${pkgs.postgresql_16}/bin/pg_dump \
          -Fc -U vaultwarden vaultwarden > "$snapshot_target/db.dump"
      ${pkgs.rsync}/bin/rsync -avz "$backup_target/" "$snapshot_target"
      ${config.my-scripts.kopia-backup} "$snapshot_target" "$backup_target"
    '';
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [
      "vaultwarden"
    ];
    ensureUsers = [
      {
        name = "vaultwarden";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };

  vault-secrets.secrets.vaultwarden = {
    services = ["vaultwarden"];
    group = config.users.groups.vaultwarden.name;
  };
}
