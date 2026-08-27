# NixOS guest for the ChromeOS Baguette VM ("containerless Crostini"): crosvm
# boots this system's btrfs rootfs directly, so there is no Debian and no LXD
# container in the way. The baguette module supplies the ChromeOS guest
# integration — vshd, maitred, garcon, sommelier (X/Wayland forwarding),
# clipboard, port forwarding — plus the rootfs image builders. The dev
# environment is the same shared profile the Coder guest uses.
#
# Bootstrap: download the upstream prebuilt aarch64 image (or build
# .#packages.aarch64-linux.baguette-zimage on any aarch64-linux host), put
# baguette_rootfs.img.zst in the ChromeOS Downloads folder, then in crosh:
#   vmc create --vm-type BAGUETTE --size 20G \
#     --source /home/chronos/user/MyFiles/Downloads/baguette_rootfs.img.zst baguette
#   vmc start --vm-type BAGUETTE baguette
# Once it boots, this config takes over in place:
#   sudo nixos-rebuild switch --flake .#chromebook
{
  pkgs,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.nixos-crostini.nixosModules.baguette
    inputs.home-manager.nixosModules.home-manager
    ../modules/options.nix
    ../modules/nixos/nix-settings.nix
  ];

  # The baguette module sets this to "baguette-nixos" with mkDefault.
  networking.hostName = "chromebook";

  # Size of the *built* rootfs image, in MiB. This is not the VM's disk: the
  # baguette module's activation script runs `btrfs filesystem resize max /` on
  # every boot, so the filesystem grows to whatever `vmc create --size` handed
  # the VM. The image only has to hold the initial closure, and it is zstd
  # compressed for transport, so unwritten space costs almost nothing. The
  # module's 4096 default is still too small once helix's language servers and
  # yazelix are in the closure. Only relevant when building an image; bootstrap
  # from the upstream prebuilt image and this is never used.
  virtualisation.diskImageSize = 12288;

  machines.username = username;

  # `vmc start` creates this account imperatively on first boot; declaring it
  # here keeps the shell, groups and home-manager profile under NixOS's
  # control. The name must match the username ChromeOS uses for Linux, or the
  # ChromeOS-side integration (shared folders, Terminal) attaches to a
  # different account than the one this config configures.
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = ["wheel" "netdev" "video" "audio"];
    # Keep the user manager (and its sommelier/garcon units) alive without an
    # open shell session.
    linger = true;
    shell = pkgs.fish;
  };

  # The upstream prebuilt Baguette image declares its own account (`aldur`, from
  # nixos-crostini's configuration.nix), and that is the account ChromeOS
  # attached to on first boot. garcon and sommelier are *user* units running
  # under it, and garcon is part of what ChromeOS waits on to consider the VM
  # up. NixOS removes users it previously managed once they leave the config, so
  # declaring only `username` here deletes that account mid-switch, tears down
  # its user manager, and the VM stops signalling readiness -- `vmc start` then
  # fails with "timeout while waiting for a signal" even though the system is
  # otherwise fine. Keep the image's account declared until it is confirmed that
  # ChromeOS is using `username` instead, then this block can go.
  users.users.aldur = {
    isNormalUser = true;
    home = "/home/aldur";
    extraGroups = ["wheel" "netdev" "video" "audio"];
    linger = true;
    shell = pkgs.fish;
  };

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [curl git];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs username;
      hostname = "chromebook";
      system = "aarch64-linux";
    };
    users.${username} = import ../home/chromebook.nix;
  };

  # Fresh system: this guest has no state predating the Baguette image.
  system.stateVersion = "25.05";
}
