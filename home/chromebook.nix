# Chromebook home profile for the ChromeOS Baguette VM. Gets the whole CLI env
# -- including git identity -- from modules/home/dev.nix, and keeps only what is
# true of this guest alone: it is small, and it has no YubiKey and no sops age
# key, so commits stay unsigned. Clipboard, xdg-open and the X/Wayland bridge
# come from the baguette module rather than from this profile.
{
  inputs,
  lib,
  username,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ../modules/home/options.nix
    ../modules/home/shell.nix
    ../modules/home/dev.nix
  ];

  home = {
    # mkDefault so the NixOS home-manager module's values (taken from
    # users.users.${username} in hosts/chromebook.nix) win, matching the
    # pattern in home/coder.nix.
    username = lib.mkDefault username;
    homeDirectory = lib.mkDefault "/home/${username}";
    stateVersion = "25.05";
  };

  programs = {
    # dev.nix leaves git signing unset (mkDefault null); no YubiKey reaches
    # this guest, so keep commits unsigned.
    git.signing.signByDefault = lib.mkForce false;

    # yazelix's home-manager module builds its runtime configs by reading from
    # an input source during activation, which `nix flake check` cannot resolve
    # ("path ... is not valid") once this host is a real nixosConfigurations
    # output. coderNixos dodges that by not being an output and
    # homeConfigurations are invisible to flake check, so this is the first
    # place CI ever evaluates it. Dropping it here also buys back store on a
    # 20G VM; yazi is configured separately in dev.nix and survives, and helix
    # reads ~/.config/helix here rather than the yazelix-managed config tree.
    # discovery and coder keep yazelix.
    yazelix.enable = lib.mkForce false;

    # yazelix was the only thing pulling in the multiplexer.
    zellij.enable = true;
  };

  # The language catalog in modules/home/helix.nix is sized for a
  # workstation. On a 20G VM the heavyweights cost more store than they earn
  # on a machine that mostly sees this repo: rust drags in rustc and cargo, c
  # drags in LLVM, ltex is a JVM app, and python / typescript / html / css /
  # docker each bring Node. Keep the languages this host actually edits --
  # Nix, Go, Terraform/HCL, shell, YAML, Markdown, Lua -- and drop the rest.
  # These stay enabled on discovery and coder; delete an entry to get one back.
  dev.helix = {
    disable = [
      "c"
      "css"
      "docker"
      "html"
      "ltex"
      "python"
      "rust"
      "typescript"
      "zig"
    ];

    # Linters for languages this host keeps but doesn't need audited.
    # golangci-lint and yamllint stay: they cover what it still edits.
    disableLinters = [
      "ansible-lint"
      "tfsec"
    ];
  };
}
