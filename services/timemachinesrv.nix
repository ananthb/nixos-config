{
  config,
  lib,
  ...
}: {
  services = {
    avahi = {
      enable = true;
      publish = {
        enable = true;
        userServices = true;
      };
      extraServiceFiles = {
        timemachine = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">%h</name>
            <service>
              <type>_smb._tcp</type>
              <port>445</port>
            </service>
            <service>
              <type>_adisk._tcp</type>
              <port>9</port>
              <txt-record>sys=waMa=0,adVF=0x100</txt-record>
              <txt-record>dk0=adVN=timemachine,adVF=0x82</txt-record>
            </service>
          </service-group>
        '';
      };
    };

    # Time Machine server via Samba
    samba = {
      enable = true;
      nmbd.enable = false;
      openFirewall = lib.mkDefault false;
      settings = {
        global = {
          "server string" = "Time Machine";
          "server role" = "standalone server";

          # Guest access
          "map to guest" = "Bad User";

          # macOS compatibility
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:aapl" = "yes";
          "fruit:nfs_aces" = "no";
          "fruit:model" = "MacSamba";

          # Performance
          "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
          "use sendfile" = "yes";
        };

        timemachine = {
          path = "/srv/timemachine";
          browseable = "yes";
          writeable = "yes";
          public = "yes";
          "guest ok" = "yes";
          "force user" = "nobody";
          "force group" = "nogroup";
          "create mask" = "0666";
          "directory mask" = "0777";
          "fruit:time machine" = "yes";
          "fruit:time machine max size" = "1T";
        };
      };
    };
  };

  my-services.kediTargets.samba-smbd = true;

  systemd = {
    tmpfiles.rules = [
      "d /srv/timemachine 0777 nobody ${config.users.groups.nogroup.name} -"
    ];

    services.samba-smbd = {
      after = ["tailscaled.service"];
      wants = ["tailscaled.service"];
      partOf = ["kedi.target"];
      unitConfig.ConditionPathIsMountPoint = "/srv";
    };
  };
}
