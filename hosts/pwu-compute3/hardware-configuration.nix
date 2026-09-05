# pwu-compute3 — the box that is still called endeavour.
#
# Copied from ananthb/machines nix/hosts/endeavour/hardware-configuration.nix,
# which is what the machine is running today. The disks and their UUIDs are the
# same physical hardware; this file is the half of the config that must NOT
# drift from the running system, because getting it wrong is the one class of
# mistake that does not fail safe.
#
# Dropped on the way across: the /var/lib/immich bind mount. It belongs with
# the immich service rather than with the disks, and immich has not moved yet.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "uas"
        "sd_mod"
        "sr_mod"
      ];

      luks.devices."root".device = "/dev/disk/by-uuid/66969cad-e8ba-4a5f-b5e1-a353d09f2384";
    };

    # This box routes for the containers it hosts.
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/63de0249-73cc-4608-b228-a9d26f8b110c";
      fsType = "btrfs";
      options = [
        "noatime"
        "compress=zstd"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/E445-A150";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    # The 27 TiB array. Already exported over NFSv4 to the pwu cluster from the
    # machines-side config, and registered with Nomad as the endeavour-srv and
    # endeavour-media host volumes (calculon-tech/platform).
    "/srv" = {
      device = "UUID=f87d0bd3-722c-40b5-b298-9ce396f34003";
      fsType = "bcachefs";
    };
  };

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
  };
}
