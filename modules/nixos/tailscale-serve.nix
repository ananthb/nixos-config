# Tailscale serve config module.
# Note: the underlying module needs `hostname` which it reads from
# config.networking.hostName, so consumers must set that.
{config, ...}: let
  tailscaleServeLib = import ../../lib/tailscale-serve-config.nix;
  hostname = config.networking.hostName;
in {
  imports = [
    (tailscaleServeLib.mkTailscaleServeConfig {inherit hostname;})
  ];
}
