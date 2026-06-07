{
  description = "Reusable NixOS / nix-darwin / home-manager modules, services, and helpers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yazelix = {
      url = "github:luccahuguet/yazelix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    starla = {
      url = "github:ananthb/starla";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        git-hooks.follows = "git-hooks";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
    ...
  }: let
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    nixosModules = {
      default = ./modules/nixos;
      options = ./modules/options.nix;
      scripts = ./modules/nixos/scripts.nix;
      cftunnel = ./modules/nixos/cftunnel.nix;
      tailscale-serve = ./modules/nixos/tailscale-serve.nix;
      service-target = ./modules/nixos/service-target.nix;
      rclone-sync = ./modules/nixos/rclone-sync.nix;
      nix-settings = ./modules/nixos/nix-settings.nix;

      actual = ./services/actual.nix;
      caddy = ./services/caddy.nix;
      esphome = ./services/esphome.nix;
      frigate = ./services/frigate.nix;
      gcloud-oauth = ./services/gcloud-oauth.nix;
      hass = ./services/hass.nix;
      homepage = ./services/homepage.nix;
      immich = ./services/immich.nix;
      immich-ml = ./services/immich-ml.nix;
      logiops = ./services/logiops.nix;
      mealie = ./services/mealie.nix;
      mosquitto = ./services/mosquitto.nix;
      radicale = ./services/radicale.nix;
      searxng = ./services/searxng.nix;
      seafile = ./services/seafile;
      timemachinesrv = ./services/timemachinesrv.nix;
      vault = ./services/vault.nix;
      vaultwarden = ./services/vaultwarden.nix;

      media-arr = ./services/media/arr.nix;
      media-jellyfin = ./services/media/jellyfin.nix;
      media-news = ./services/media/news.nix;

      monitoring-blackbox = ./services/monitoring/blackbox.nix;
      monitoring-ecoflow = ./services/monitoring/ecoflow.nix;
      monitoring-grafana = ./services/monitoring/grafana.nix;
      monitoring-libvirt = ./services/monitoring/libvirt.nix;
      monitoring-postgres = ./services/monitoring/postgres.nix;
      monitoring-probes = ./services/monitoring/probes.nix;
      monitoring-victoriametrics = ./services/monitoring/victoriametrics.nix;
    };

    homeManagerModules = {
      default = ./modules/home;
      options = ./modules/home-options.nix;
      shell = ./modules/home/shell.nix;
      dev = ./modules/home/dev.nix;
    };

    darwinModules = {
      # Platform-agnostic option declarations; aliased so darwin hosts can
      # import them without going through nixosModules.
      options = ./modules/options.nix;
    };
  in {
    inherit nixosModules homeManagerModules darwinModules;

    lib = {
      containerImages = import ./lib/container-images.nix;
      mkCaddyReverseProxies = import ./lib/caddy-helpers.nix;
      inherit (import ./lib/caddy-ddns.nix) mkCaddyDdns;
    };

    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        doc = pkgs.stdenv.mkDerivation {
          name = "nixos-config-doc";
          src = ./doc;
          nativeBuildInputs = [pkgs.mdbook];
          buildPhase = "mdbook build";
          installPhase = "cp -r book $out";
        };
      }
    );

    apps = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        doc-serve = {
          type = "app";
          meta.description = "Serve the nixos-config documentation locally with live reload";
          program = let
            serve = pkgs.writeShellApplication {
              name = "doc-serve";
              runtimeInputs = [pkgs.mdbook];
              text = ''
                cd ${./doc}
                mdbook serve --open
              '';
            };
          in "${serve}/bin/doc-serve";
        };
      }
    );

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    checks = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        formatterPkg = self.formatter.${system};
      in {
        pre-commit = self.devShells.${system}.default.passthru.preCommitCheck;
        formatting = pkgs.runCommand "check-formatting" {buildInputs = [formatterPkg];} ''
          ${pkgs.lib.getExe formatterPkg} --check ${self}
          touch $out
        '';
        statix = pkgs.runCommand "check-statix" {buildInputs = [pkgs.statix];} ''
          statix check ${self}
          touch $out
        '';
        deadnix = pkgs.runCommand "check-deadnix" {buildInputs = [pkgs.deadnix];} ''
          deadnix --fail ${self}
          touch $out
        '';
      }
    );

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        formatterPkg = self.formatter.${system};
        preCommitCheck = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            statix.enable = true;
            deadnix.enable = true;
          };
        };
      in {
        default = pkgs.mkShell {
          inherit (preCommitCheck) shellHook;
          passthru = {inherit preCommitCheck;};
          packages =
            preCommitCheck.enabledPackages
            ++ [
              formatterPkg
              pkgs.statix
              pkgs.deadnix
              pkgs.mdbook
            ];
        };
      }
    );
  };
}
