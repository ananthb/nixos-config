# Caddy with dynamic DNS for IPv6
# Creates a NixOS module that configures Caddy with cloudflare DDNS
# for keeping AAAA records up to date with the host's IPv6 address.
#
# Usage:
#   imports = [ (lib/caddy-ddns.nix).mkCaddyDdns { domains = [ "tv" "*.coder" ]; } ];
{
  mkCaddyDdns = {domains}: {
    config,
    pkgs,
    ipv6Token,
    ...
  }: let
    vs = config.vault-secrets.secrets;
    getIPv6 = pkgs.writeShellScript "get-ipv6" ''
      # ------------------------------------------------------------------------
      # ddns custom IPv6 getter
      # Returns all GUA (Global Unicast Address) IPv6 addresses
      # filtered by the token set for this host (${ipv6Token})
      # GUA addresses are in the 2000::/3 range (start with 2 or 3)
      # ------------------------------------------------------------------------

      ${pkgs.iproute2}/bin/ip -6 addr show scope global | \
        ${pkgs.gawk}/bin/awk '
          /inet6 [23].*${ipv6Token}\// {
            sub(/\/.*$/, "", $2);
            if (out == "") out = $2; else out = out "," $2;
          }
          END { if (out != "") print out; }
        '
    '';

    domainList = builtins.concatStringsSep " " domains;
  in {
    imports = [../services/caddy.nix];

    services.caddy = {
      enable = true;
      package = let
        withPlugins = pkgs.callPackage (pkgs.path + "/pkgs/by-name/ca/caddy/plugins.nix") {inherit (pkgs) caddy;};
      in
        withPlugins {
          plugins = [
            "github.com/mholt/caddy-dynamicdns@v0.0.0-20251020155855-d8f490a28db6"
            "github.com/mietzen/caddy-dynamicdns-cmd-source@v0.2.0"
            "github.com/caddy-dns/cloudflare@v0.2.2"
            "github.com/Elegant996/scgi-transport@v1.1.9"
          ];
          hash = "sha256-5G6noyFTpvq/ZdvG0aY5cuQ5P+OZR4xReJCqOgxfp5M=";
        };

      globalConfig = ''
        email srv.acme@kedi.dev
        acme_ca https://acme-v02.api.letsencrypt.org/directory

        dynamic_dns {
          provider cloudflare {$CLOUDFLARE_API_TOKEN}
          domains {
            kedi.dev ${domainList}
          }
          ip_source command ${getIPv6}
          versions ipv6
          check_interval 5m
        }
      '';
    };

    systemd.services.caddy.serviceConfig = {
      EnvironmentFile = "${vs.caddy-ddns}/environment";
    };

    networking.firewall.allowedTCPPorts = [443];

    vault-secrets.secrets.caddy-ddns = {
      services = ["caddy"];
    };
  };
}
