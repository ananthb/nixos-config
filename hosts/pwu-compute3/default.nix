# pwu-compute3 — the third compute node of the pwu cluster.
#
# Physically this is the box that has been called endeavour: an Intel desktop
# with a 27 TiB bcachefs array at /srv, sitting on the pwu LAN at
# 192.168.31.251. It is being rebuilt as a cluster node rather than renamed
# into one, which is why this is a new host here instead of a moved directory.
#
# Nothing deploys this yet. ananthb/machines still owns the running system and
# is deliberately kept at the configuration that box is actually running, so
# there is a known-good state to fall back to. This host is built out until it
# is worth cutting over, and the cutover is its own deliberate act.
#
# What is different here, and why the rebuild is worth doing at all:
#
#   - No self-hosted Vault. The machines-side config runs a single-node raft
#     Vault on this box, TPM-unsealed, holding every service credential. Here
#     the host is a client of the pwu cluster Vault -- see vault-agent.nix.
#   - No sops. With Vault remote, the only bootstrap secrets are the two
#     AppRole files, so there is no host key to encrypt to and no
#     secrets/<host>.yaml to keep in sync.
#   - It joins the cluster: Consul client, then Nomad client, then the media
#     and photo services move in as Nomad jobs pinned to this node so they read
#     the array locally instead of over a 100 Mb/s link.
#
# See calculon-tech/platform doc/endeavour-migration.md for the phase plan.
{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  cfg = config.machines;
in {
  imports = [
    ../../modules/options.nix
    ../../modules/nixos/nix-settings.nix

    ./hardware-configuration.nix
    ./vault-agent.nix
  ];

  # ---------------------------------------------------------------------------
  # Boot
  #
  # UNRESOLVED, AND THE MOST DANGEROUS THING IN THIS FILE.
  #
  # The disk this config would land on is currently booted by lanzaboote with
  # Secure Boot enabled, signed with keys in /var/lib/sbctl (ananthb/machines,
  # nix/hosts/shared/lanzaboote.nix). systemd-boot below is NOT that. Switching
  # a machine from lanzaboote to plain systemd-boot while the firmware still
  # enforces Secure Boot installs an unsigned bootloader and the box does not
  # come back -- and this machine has no out-of-band access, unlike
  # pwu-compute1 which has pwu-kvm1. Recovery is a physical trip.
  #
  # So this is here to make the configuration evaluate, not because it is the
  # answer. Before anything switches, one of these has to be chosen on purpose:
  # carry lanzaboote across (a new flake input and the sbctl key material), or
  # turn Secure Boot off in firmware first, in person, and then switch.
  # ---------------------------------------------------------------------------
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = hostname;
    useNetworkd = true;
    useDHCP = true;

    # Nothing is exposed to the LAN by default. The NFS export of /srv opens
    # 2049 on the wired interfaces when it moves across; until then this host
    # offers nothing but ssh over the tailnet.
    firewall.enable = true;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Vault lives on the cluster now, reached over the tailnet.
  machines.vaultAgent.enable = true;

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_IN.UTF-8";

  # gid 985 is the array's write identity: /srv/media carries POSIX default
  # ACLs granting this group, and it is what the NFS clients' tasks run as.
  # Pinned rather than allocated, because the number is baked into the
  # filesystem and into the jobs on the other end of the export.
  users.groups.media.gid = 985;

  users.users.${cfg.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "media"
    ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # No sudo, same as the running box: the keys that authenticate to sshd are
  # resident on a YubiKey, and a password prompt on a headless machine is a
  # lockout waiting to happen. wheel gets root through polkit instead, which
  # run0 uses and which works non-interactively over ssh.
  security = {
    sudo.enable = false;
    polkit.enable = true;
  };

  environment.systemPackages = with pkgs; [
    bcachefs-tools
    vault
  ];

  # Deliberately NOT set: system.autoUpgrade. The machines-side host pulls and
  # switches on a timer; this one does not, and must not, until the cutover is
  # a decision someone has made rather than something that happened at 02:00.
  system.stateVersion = lib.mkDefault "25.05";
}
