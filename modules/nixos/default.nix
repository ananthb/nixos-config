{...}: {
  imports = [
    ../options.nix
    ./scripts.nix
    ./cftunnel.nix
    ./tailscale-serve.nix
    ./service-target.nix
    ./rclone-sync.nix
    ./nix-settings.nix
  ];
}
