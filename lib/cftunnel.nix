# To add a new tunnel:
# 1. cloudflared tunnel login <the-token-you-see-in-dashboard>
# 2. cloudflared tunnel create ConvenientTunnelName
# 3. Set my-services.cftunnelConfig in the host module (tunnel ID/name + ingress map)
# 4. Add the credentials to Vault (vault-secrets) under the tunnel secret path
#
# For browser-based RDP:
# - Add a Private Network route in Cloudflare Zero Trust dashboard (Networks → Tunnels → Private Network)
# - Add an Access Target (Access → Infrastructure → Targets) for the RDP host IP
# - Create an Access Application with Browser Rendering → RDP enabled
{
  mkCftunnel = {
    config,
    lib,
    ...
  }: let
    inherit (lib) mkOption types;
    cfg = config.my-services.cftunnelConfig;
    vs = config.vault-secrets.secrets;
    tunnelType = types.submodule (_: {
      options = {
        tunnelId = mkOption {
          type = types.str;
          description = "Cloudflare tunnel UUID.";
        };
        tunnelName = mkOption {
          type = types.str;
          description = "Human-friendly tunnel name.";
        };
        ingress = mkOption {
          type = types.attrsOf types.str;
          description = "Ingress map of hostname to upstream URL.";
        };
      };
    });
  in {
    options.my-services.cftunnelConfig = mkOption {
      type = types.nullOr (types.listOf tunnelType);
      default = null;
      description = "Cloudflare tunnel configuration for this host.";
    };

    config = lib.mkIf (cfg != null) {
      services.cloudflared = {
        enable = true;
        tunnels = builtins.listToAttrs (
          map (tunnelCfg: {
            name = tunnelCfg.tunnelId;
            value = {
              default = "http_status:404";
              inherit (tunnelCfg) ingress;
              credentialsFile = "${vs."cloudflare-tunnel-${tunnelCfg.tunnelId}"}/credentials";
            };
          })
          cfg
        );
      };

      vault-secrets.secrets = builtins.listToAttrs (
        map (tunnelCfg: {
          name = "cloudflare-tunnel-${tunnelCfg.tunnelId}";
          value = {
            services = ["cloudflared-tunnel-${tunnelCfg.tunnelId}"];
          };
        })
        cfg
      );
    };
  };
}
