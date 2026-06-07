# Generates Caddy virtualHosts for simple reverse proxy patterns.
# Usage:
#   services.caddy.virtualHosts = mkCaddyReverseProxies {
#     "app.example.com" = 3000;
#     "api.example.com" = 8080;
#   };
{lib}:
lib.mapAttrs' (hostname: port: {
  name = "${hostname}:80";
  value.extraConfig = "reverse_proxy localhost:${toString port}";
})
