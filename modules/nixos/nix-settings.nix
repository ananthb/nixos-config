# Shared nix settings for all platforms (NixOS, Darwin).
# nixpkgs.config (allowUnfree, overlays) is set in flake.nix via pkgsFor.
_: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://ananthb.cachix.org"
        "https://nix-community.cachix.org"
        "https://lanzaboote.cachix.org"
      ];
      trusted-public-keys = [
        "ananthb.cachix.org-1:3xWOBNIZww9cR1M82NgG4PtJ266LU9Ec30BrTON4ODA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lanzaboote.cachix.org-1:DaO+aH1QRT1iuKv/+/QqlqHwhBVm3sw5pZf//jPVRnA="
      ];
    };

    gc.automatic = true;
    optimise.automatic = true;
  };
}
