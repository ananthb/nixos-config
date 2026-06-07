# Frigate NVR as a Podman container managed by quadlet.
# Hosts import this and set my-services.frigate.settings with their
# camera-specific Frigate YAML config.
{
  config,
  containerImages,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my-services.frigate;

  frigateConfig = pkgs.writeText "frigate-config.yml" (builtins.toJSON (cfg.settings
    // {
      database.path = "/db/frigate.db";
    }));

  inherit (config.virtualisation.quadlet) volumes;
in {
  options.my-services.frigate = {
    enable = lib.mkEnableOption "Frigate NVR (Podman container)";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Frigate configuration (converted to YAML config.yml).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/frigate 0755 root root - -"
    ];

    systemd.services.frigate-config = {
      description = "Copy Frigate config";
      wantedBy = ["frigate.service"];
      before = ["frigate.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/cp ${frigateConfig} /var/lib/frigate/config.yml";
      };
    };

    virtualisation.quadlet = {
      volumes.frigate-db = {};

      containers.frigate = {
        containerConfig = {
          name = "frigate";
          image = containerImages.frigate;
          autoUpdate = "registry";
          networks = ["host"];
          volumes = [
            "/var/lib/frigate/config.yml:/config/config.yml"
            "${volumes.frigate-db.ref}:/db"
            "/srv/frigate/recordings:/media/frigate/recordings"
            "/srv/frigate/clips:/media/frigate/clips"
            "/srv/frigate/exports:/media/frigate/exports"
          ];
          environments.FRIGATE_RTSP_PASSWORD = "";
          devices = ["/dev/dri:/dev/dri"];
          podmanArgs = ["--shm-size=256m" "--privileged" "--tmpfs=/tmp/cache:size=2g"];
        };
        unitConfig = {
          RequiresMountsFor = "/srv";
          After = ["frigate-config.service"];
          Requires = ["frigate-config.service"];
        };
        serviceConfig.Restart = "on-failure";
      };
    };
  };
}
