{
  lib,
  pkgs,
  ...
}: {
  services.prometheus.exporters.libvirt = {
    enable = true;
    openFirewall = true;
  };

  # The exporter user needs the libvirtd group in its user definition
  # (not just SupplementaryGroups) so polkit recognizes it.
  users.users.prometheus-libvirt-exporter = {
    isSystemUser = true;
    group = "prometheus-libvirt-exporter";
    extraGroups = ["libvirtd"];
  };
  users.groups.prometheus-libvirt-exporter = {};

  systemd.services.prometheus-libvirt-exporter.serviceConfig = {
    ExecStart = lib.mkForce ''
      ${pkgs.prometheus-libvirt-exporter}/bin/libvirt-exporter \
        --web.listen-address [::]:9177
    '';
    RestrictAddressFamilies = lib.mkForce [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
  };
}
