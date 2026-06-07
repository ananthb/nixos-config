{
  config,
  pkgs,
  username,
  ...
}: let
  vs = config.vault-secrets.secrets;
in {
  imports = [
    ((import ../../lib/caddy-ddns.nix).mkCaddyDdns {domains = ["tv"];})
  ];

  users.groups.media.members = [
    username
  ];

  environment.systemPackages = [
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];

  # jellyfin-web intro-skipper overlay is in flake.nix pkgsFor.

  services = {
    jellyfin = {
      enable = true;
      group = "media";
      openFirewall = true;
    };

    tsnsrv = {
      enable = true;
      defaults.authKeyPath = "${vs.tailscale-api}/auth_key";
      defaults.urlParts.host = "localhost";
      services.tv = {
        funnel = true;
        urlParts.port = 8096;
      };
    };

    caddy.virtualHosts."tv.kedi.dev" = {
      extraConfig = ''
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options    "nosniff"
          X-XSS-Protection          "1; mode=block"
        }

        reverse_proxy localhost:8096
      '';
    };
  };

  my-services.kediTargets.jellyfin = true;
  my-services.kediTargets.tsnsrv-tv = true;

  systemd.services = {
    jellyfin = {
      partOf = ["kedi.target"];
      serviceConfig.SupplementaryGroups = ["media"];
    };
    caddy = {
      after = ["jellyfin.service"];
      wants = ["jellyfin.service"];
      partOf = ["kedi.target"];
    };
    tsnsrv-tv = {
      wants = ["jellyfin.service"];
      after = ["jellyfin.service"];
      partOf = ["kedi.target"];
      serviceConfig.SupplementaryGroups = ["media"];
    };
  };

  vault-secrets.secrets.tailscale-api = {
    services = [
      "tsnsrv-tv"
    ];
    group = "media";
  };
}
