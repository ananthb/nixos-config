{
  config,
  pkgs,
  ...
}: {
  nix-homebrew = {
    enable = true;
    mutableTaps = false;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    taps = builtins.attrNames config.nix-homebrew.taps;
  };

  environment.systemPackages = [pkgs.mas];
}
