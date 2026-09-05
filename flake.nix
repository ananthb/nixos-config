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
      url = "github:aldur/nixos-crostini";
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
            "claude"
            "claude-code"
            "codex"
            "codex-app"
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

    # Full NixOS guest for the Coder dev workspace: systemd PID 1, the coder
    # agent as a service, dev env via home-manager. Kept as a let-binding rather
    # than a nixosConfigurations output. That was originally to dodge yazelix's
    # import-from-derivation activation under `nix flake check --no-build`;
    # yazelix is gone, so this could likely become a real output now -- left as
    # is because nothing depends on it being one. It is still reusable as
    # nixosModules.coder-vm and built via the coder-image package.
    coderNixos = nixpkgs.lib.nixosSystem {
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

    # Compressed btrfs rootfs for `vmc create --vm-type BAGUETTE --source`.
    # Buildable on any aarch64-linux host, including from inside the VM itself.
    packages.aarch64-linux.baguette-zimage =
      self.nixosConfigurations.chromebook.config.system.build.btrfsImageCompressed;

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
    # system with the coder-agent service. Built and pushed to GHCR by the
    # private platform repo's coder-images workflow.
    packages.x86_64-linux.coder-image = let
      pkgs = pkgsFor "x86_64-linux";
      system = coderNixos.config.system.build.toplevel;

      # Docker mounts /sys/fs/cgroup READ-ONLY for unprivileged containers --
      # under runc and under kata alike, and --cgroupns=host does not change it.
      # systemd as PID 1 cannot create its slices on a read-only cgroup2 tree, so
      # it exits immediately with status 255 and prints NOTHING: the last line in
      # the container log is stage 2's own "starting systemd...", which reads
      # like the image is fine and the agent is at fault. Remount it first.
      #
      # The remount needs CAP_SYS_ADMIN, which the workspace jobspec grants with
      # cap_add = ["sys_admin"]; that same capability is what lets stage 2 mount
      # /proc, /dev and /run at all. If it is missing, say so on stderr rather
      # than handing over to a systemd that will die silently.
      init = pkgs.writeShellScript "coder-init" ''
        if ! ${pkgs.util-linux}/bin/mount -o remount,rw /sys/fs/cgroup; then
          echo "coder-init: could not remount /sys/fs/cgroup read-write." >&2
          echo "coder-init: systemd will exit 255 without logging. The container" >&2
          echo "coder-init: needs CAP_SYS_ADMIN -- cap_add = [\"sys_admin\"]." >&2
        fi

        exec ${system}/init "$@"
      '';
    in
      pkgs.dockerTools.buildLayeredImage {
        name = "coder-nixos";
        tag = "latest";
        # Ship /nix/var/nix/db. Without it every path in the guest's store is
        # "invalid" to nix, so `nix-store --verify --check-contents` reports
        # nothing and `--repair-path` refuses to run -- which is how a starship
        # binary that had been truncated to 4521984 of its 15003888 bytes
        # (a clean page boundary, so a partial extract) sat there segfaulting
        # `starship init fish` on every new shell with no way to find it or any
        # other damaged path. Costs a few MB of image and makes the store
        # verifiable and repairable in place.
        includeNixDB = true;
        # `init` is deliberately NOT in contents: entries there are copied into
        # the rootfs and must be directories, so a bare script fails the
        # customisation layer with "Not a directory". It does not need to be --
        # streamLayeredImage takes its closure roots from contents AND the
        # config, so referencing it from Cmd is enough to put it in a layer.
        contents = [system];
        config.Cmd = [init];
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
