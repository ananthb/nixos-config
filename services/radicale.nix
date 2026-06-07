{
  config,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  services.radicale = {
    enable = true;
    settings = {
      server.hosts = ["[::]:5232"];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "${vs.radicale}/htpasswd";
        htpasswd_encryption = "autodetect";
      };
    };
  };

  my-services.kediTargets.radicale = true;

  systemd.services.radicale = {
    partOf = ["kedi.target"];
  };

  systemd.services."radicale-backup" = config.my-services.mkBackupService {
    stopService = "radicale";
    extraPath = [pkgs.systemd];
    script = ''
      backup_target="/var/lib/radicale"
      snapshot_target="$(${pkgs.mktemp}/bin/mktemp -d)"
      trap '{ rm -rf "$snapshot_target"; }' EXIT
      ${pkgs.rsync}/bin/rsync -avz "$backup_target/" "$snapshot_target"
      ${config.my-scripts.kopia-backup} "$snapshot_target" "$backup_target"
    '';
  };

  vault-secrets.secrets.radicale = {
    services = ["radicale"];
    group = config.users.groups.radicale.name;
  };
}
