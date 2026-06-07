# To add a new serve config:
# - Set my-services.tailscaleServeConfig in the host module
{
  mkTailscaleServeConfig = {hostname}: {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkOption types;
    cfg = config.my-services.tailscaleServeConfig;
    serveConfigPath = pkgs.writeText "tailscale-serve-config-${hostname}.json" (builtins.toJSON cfg);
  in {
    options.my-services.tailscaleServeConfig = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Tailscale serve config, written to JSON and applied at boot.";
    };

    config = lib.mkIf (cfg != null) {
      systemd.services.tailscale-serve-config = {
        description = "Apply Tailscale serve config";
        wantedBy = ["multi-user.target"];
        after = ["tailscaled.service"];
        wants = ["tailscaled.service"];
        restartIfChanged = true;
        serviceConfig = {
          Type = "oneshot";
          # Wait for tailscaled to be logged in before applying serve config.
          ExecStartPre = ''
            ${pkgs.bash}/bin/bash -lc '
              for i in {1..60}; do
                state="$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r .BackendState)"
                if [ "$state" = "Running" ]; then
                  exit 0
                fi
                sleep 2
              done
              exit 1
            '
          '';
          ExecStart = "${pkgs.tailscale}/bin/tailscale serve set-config --all ${serveConfigPath}";
        };
      };
    };
  };
}
