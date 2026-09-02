# NixOS guest for the ChromeOS Baguette VM ("containerless Crostini"): crosvm
# boots this system's btrfs rootfs directly, so there is no Debian and no LXD
# container in the way. The baguette module supplies the ChromeOS guest
# integration — vshd, maitred, garcon, sommelier (X/Wayland forwarding),
# clipboard, port forwarding — plus the rootfs image builders. The dev
# environment is the same shared profile the Coder guest uses.
#
# Bootstrap: download the image straight into the ChromeOS Downloads folder,
#   https://github.com/ananthb/nixos-config/releases/latest/download/baguette_rootfs.img.zst
# leaving it compressed, since vmc reads the .zst as-is. Then in crosh:
#   vmc create --vm-type BAGUETTE --size 20G \
#     --source /home/chronos/user/MyFiles/Downloads/baguette_rootfs.img.zst baguette
#   vmc start --vm-type BAGUETTE baguette
# Once it boots, this config takes over in place:
#   sudo nixos-rebuild switch --flake .#chromebook
# .github/workflows/baguette-image.yml builds that asset on a hosted
# aarch64-linux runner every time a release is published, because nothing local
# can: the image is aarch64-linux and the machine that manages this repo is
# aarch64-darwin with no linux-builder. After changing this config, publish a
# fresh one with `gh release create <tag>`. To build the same image by hand, on
# any aarch64-linux machine including a Baguette VM that is already running:
#   nix build .#packages.aarch64-linux.baguette-zimage
#
# Do not bootstrap from nixos-crostini's own prebuilt image. It ships their
# placeholder `aldur` as uid 1000, and `vmc start` binds the ChromeOS-side
# integration to whichever account it set up on first boot -- so ChromeOS would
# end up talking to `aldur` while home-manager configures `username`, and
# switching this config onto it deletes `aldur` besides (see below). Our image
# has `username` at uid 1000 from the first boot, so the ChromeOS account and
# the configured account are the same one. If you do boot theirs anyway, take
# `aldur` out of the NixOS-managed set before switching:
#   sudo sh -c \
#     "tr ' ' '\n' </var/lib/nixos/declarative-users | grep -vx aldur \
#      | paste -sd' ' >/var/lib/nixos/declarative-users"
# after which mutableUsers (on by default) leaves the account alone.
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
  # module's 4096 default is still too small once helix's language servers are
  # in the closure. Only relevant when building an image; bootstrap
  # from the upstream prebuilt image and this is never used.
  virtualisation.diskImageSize = 12288;

  machines.username = username;

  # The ChromeOS-side account. `vmc start` sets it up on first boot by running
  # usermod against the image's uid 1000 user -- that is what the
  # /usr/sbin/usermod hack in the baguette module exists for -- so this is the
  # account the built image has to ship, and the name has to match the username
  # ChromeOS uses for Linux, or the ChromeOS-side integration (shared folders,
  # Terminal) attaches to a different account than the one this config
  # configures. Declaring it here keeps the shell, groups and home-manager
  # profile under NixOS's control.
  #
  # Never drop the account a running VM is attached to as part of a switch.
  # update-users-groups.pl deletes any user listed in
  # /var/lib/nixos/declarative-users that is no longer declared -- mutableUsers
  # only protects users NixOS never declared, so it does not save you here.
  # Losing that account tears down its user manager and with it the garcon and
  # sommelier units ChromeOS waits on to consider the VM up, and `vmc start`
  # then fails with "timeout while waiting for a signal" even though the system
  # is otherwise fine. Change the account by building a fresh image and
  # recreating the VM, per the bootstrap notes above.
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = ["wheel" "netdev" "video" "audio"];
    # Keep the user manager (and its sommelier/garcon units) alive without an
    # open shell session.
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
