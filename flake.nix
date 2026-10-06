{
  description = "Ananth's dev environment: reusable Nix modules, the discovery (nix-darwin) host, and the coder dev-VM profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    askpass-homebrew-tap = {
      url = "github:theseal/homebrew-ssh-askpass";
      flake = false;
    };

    # The Homebrew binary itself. Pinned directly (rather than left as a
    # transitive input of nix-homebrew) so it can be bumped in lockstep with
    # the homebrew-core/homebrew-cask taps via `nix flake update brew-src`.
    # The taps' formula/cask install DSL must be parseable by this brew.
    brew-src = {
      url = "github:Homebrew/brew";
      flake = false;
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

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ChromeOS Baguette ("containerless Crostini") support: the guest-side
    # integration module (vshd, maitred, garcon, sommelier) plus the btrfs
    # rootfs image builders. See hosts/chromebook.nix.
    nixos-crostini = {
      url = "github:ananthb/nixos-crostini";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    scurry = {
      url = "github:ananthb/scurry";
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

    # The Baguette VM's account has to match the one ChromeOS creates for
    # Linux, which is derived from the signed-in Google account and is `antsub`
    # on this device rather than the `ananth` used everywhere else.
    chromebookUsername = "antsub";

    systems = [
      # nixpkgs 26.11 dropped x86_64-darwin support; only aarch64 Macs remain.
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Pre-instantiate nixpkgs per system with the unfree allowlist.
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "1password"
            "antigravity-cli"
            "claude-code"
            "discord"
            "google-chrome"
            "slack"
            "terraform"
            "vault"
            "vault-bin"
            "vscode"
          ];
      };

    nixosModules = {
      options = ./modules/options.nix;
      nix-settings = ./modules/nixos/nix-settings.nix;
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
      hardening = ./modules/darwin/hardening.nix;
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
            darwinModules.hardening
            ./hosts/${hostname}.nix
          ];
      };

    moonlander = (pkgsFor "aarch64-darwin").callPackage ./keyboards/moonlander {};
  in {
    inherit nixosModules homeManagerModules darwinModules;

    darwinConfigurations.discovery = mkDarwinHost {
      hostname = "discovery";
      system = "aarch64-darwin";
    };

    # The Chromebook's ChromeOS Baguette VM. Unlike coderNixos above this is a
    # real nixosConfigurations output: the guest rebuilds itself in place with
    # `nixos-rebuild switch --flake .#chromebook`, which resolves that attr.
    nixosConfigurations.chromebook = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        username = chromebookUsername;
        hostname = "chromebook";
        system = "aarch64-linux";
      };
      modules = [
        {nixpkgs.pkgs = pkgsFor "aarch64-linux";}
        ./hosts/chromebook.nix
      ];
    };

    # pwu-compute3 — the third compute node of the pwu cluster. Built out here,
    # deployed by nobody yet: ananthb/machines still owns the running box (as
    # "endeavour") and is held at the configuration it is actually running, so
    # there is a known-good state to fall back to. Cutting over is a deliberate
    # act, not something a timer does — note the absence of system.autoUpgrade
    # in the host, and the unresolved bootloader question at the top of it.
    nixosConfigurations.pwu-compute3 = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs username;
        hostname = "pwu-compute3";
        system = "x86_64-linux";
      };
      modules = [
        {nixpkgs.pkgs = pkgsFor "x86_64-linux";}
        ./hosts/pwu-compute3
      ];
    };

    packages = {
      # Compressed btrfs rootfs for `vmc create --vm-type BAGUETTE --source`.
      # Buildable on any aarch64-linux host, including from inside the VM itself.
      aarch64-linux.baguette-zimage =
        self.nixosConfigurations.chromebook.config.system.build.btrfsImageCompressed;

      # ZSA Moonlander firmware from keyboards/moonlander. Flash with
      #   nix run .#flash-moonlander
      aarch64-darwin.moonlander-firmware = moonlander.firmware;
    };

    apps.aarch64-darwin.flash-moonlander = {
      type = "app";
      program = nixpkgs.lib.getExe moonlander.flash;
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
              pkgs.gh
              pkgs.sops
            ];
        };
      }
    );
  };
}
