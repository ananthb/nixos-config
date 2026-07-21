{
  description = "Ananth's dev environment: reusable Nix modules, the discovery (nix-darwin) host, and the coder dev-VM profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    askpass-homebrew-tap = {
      url = "github:theseal/homebrew-ssh-askpass";
      flake = false;
    };

    cosmonaut = {
      url = "github:ananthb/cosmonaut";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate Nix manages the daemon on discovery, replacing nix-darwin's
    # native Nix management (see hosts/discovery.nix).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    starla = {
      url = "github:ananthb/starla";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        git-hooks.follows = "git-hooks";
      };
    };

    yazelix = {
      url = "github:luccahuguet/yazelix/863f7fe37c19e9f001224aadb5adc0fdfc3479d2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    git-hooks,
    ...
  } @ inputs: let
    username = "ananth";

    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Pre-instantiate nixpkgs per system with the unfree allowlist and the
    # nvim-treesitter-legacy deprecation-warning shim the dev config needs.
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "1password"
            "claude"
            "claude-code"
            "codex"
            "codex-app"
            "copilot.vim"
            "discord"
            "google-chrome"
            "slack"
            "terraform"
            "vault"
            "vault-bin"
            "vscode"
          ];
        overlays = [
          # Bypass the vimPlugins.nvim-treesitter-legacy deprecation warning
          # that fires on every neovim build via vim-utils.nix's assert. We
          # don't use any plugin that needs the legacy package.
          (_: prev: {
            vimPlugins = prev.vimPlugins.extend (
              _: vprev: {
                nvim-treesitter-legacy = vprev.nvim-treesitter.overrideAttrs (_: {
                  pname = "nvim-treesitter-legacy-shim";
                });
              }
            );
          })
        ];
      };

    nixosModules = {
      options = ./modules/options.nix;
      nix-settings = ./modules/nixos/nix-settings.nix;
      # Full NixOS guest for a Coder dev workspace (systemd + coder-agent
      # service + the shared dev env). See hosts/coder.nix.
      coder-vm = ./hosts/coder.nix;
    };

    homeManagerModules = {
      default = ./modules/home;
      options = ./modules/home/options.nix;
      shell = ./modules/home/shell.nix;
      dev = ./modules/home/dev.nix;
    };

    darwinModules = {
      # Platform-agnostic option declarations; aliased so darwin hosts can
      # import them without going through nixosModules.
      options = ./modules/options.nix;
      dev = ./modules/darwin/dev.nix;
      # Wrap homebrew + host modules so they close over this flake's own inputs
      # for nix-homebrew / home-manager and their tap sources.
      homebrew = _: {
        imports = [
          inputs.nix-homebrew.darwinModules.nix-homebrew
          ./modules/darwin/homebrew.nix
        ];
        nix-homebrew.taps = {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
          "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
        };
      };
      host = _: {
        imports = [
          inputs.home-manager.darwinModules.home-manager
          ./modules/darwin/host.nix
        ];
      };
    };

    mkDarwinHost = {
      hostname,
      system,
      extraModules ? [],
    }: let
      pkgs = pkgsFor system;
      # Drop --force-cleanup (removed from brew bundle) via an eval-time text
      # substitution rather than pkgs.applyPatches, so evaluating this config
      # on a non-darwin host doesn't require an aarch64-darwin builder.
      patchedHomebrewModule = builtins.toFile "homebrew.nix" (
        builtins.replaceStrings
        ["--force-cleanup"]
        ["--cleanup"]
        (builtins.readFile "${nix-darwin}/modules/homebrew.nix")
      );
    in
      nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit system hostname username inputs;
        };
        modules =
          extraModules
          ++ [
            {nixpkgs.pkgs = pkgs;}
            darwinModules.options
            darwinModules.host
            darwinModules.homebrew
            darwinModules.dev
            ./hosts/${hostname}.nix
            {
              disabledModules = ["${nix-darwin}/modules/homebrew.nix"];
              imports = [patchedHomebrewModule];
            }
          ];
      };
  in {
    inherit nixosModules homeManagerModules darwinModules;

    darwinConfigurations.discovery = mkDarwinHost {
      hostname = "discovery";
      system = "aarch64-darwin";
    };

    # Full NixOS guest for the Coder dev workspace: systemd PID 1, the coder
    # agent as a service, dev env via home-manager. Built into the workspace
    # image consumed by private-tech/platform.
    nixosConfigurations.coder = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs username;
        hostname = "coder";
        system = "x86_64-linux";
      };
      modules = [
        {nixpkgs.pkgs = pkgsFor "x86_64-linux";}
        ./hosts/coder.nix
      ];
    };

    # Standalone home-manager profile — the same dev env as the NixOS guest
    # above, for the lightweight nix-container path or ad-hoc use. Activate with:
    #   nix run home-manager -- switch --flake github:ananthb/nixos-config#coder
    homeConfigurations."coder@x86_64-linux" = home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor "x86_64-linux";
      extraSpecialArgs = {
        inherit inputs username;
        hostname = "coder";
        system = "x86_64-linux";
      };
      modules = [./home/coder.nix];
    };

    # OCI image for the Coder NixOS workspace. Its entrypoint is the NixOS
    # container init (systemd as PID 1); the Nomad containerd/kata driver uses
    # this rootfs to boot the microVM, so the guest comes up as a full NixOS
    # system with the coder-agent service. Built + pushed to GHCR by
    # private-tech/platform's coder-images workflow.
    packages.x86_64-linux.coder-image = let
      pkgs = pkgsFor "x86_64-linux";
      system = self.nixosConfigurations.coder.config.system.build.toplevel;
    in
      pkgs.dockerTools.buildLayeredImage {
        name = "coder-nixos";
        tag = "latest";
        contents = [system];
        config.Cmd = ["${system}/init"];
      };

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
              pkgs.sops
            ];
        };
      }
    );
  };
}
