{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  secureBootEnabled = config.boot.lanzaboote.enable or false;
  inherit (config.services.vault) tpmUnseal;
  unsealScript = pkgs.writeShellScript "vault-unseal-tpm" ''
    set -euo pipefail

    umask 0077
    tmpdir="$(mktemp -d -p /run/vault-unseal vault-unseal.XXXXXX)"
    trap 'rm -rf "$tmpdir"' EXIT

    for handle in ${lib.concatStringsSep " " tpmUnseal.handles}; do
      "${pkgs.tpm2-tools}/bin/tpm2_unseal" -c "$handle" -p "pcr:sha256:${tpmUnseal.pcrs}" -o "$tmpdir/unseal.key"
      unseal_key="$(cat "$tmpdir/unseal.key")"
      "${pkgs.vault}/bin/vault" operator unseal "$unseal_key"
    done
  '';
in {
  options.services.vault.tpmUnseal = {
    enable = lib.mkEnableOption "TPM2-based boot-time unseal for Vault (OSS)";
    handles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "0x81000001"
        "0x81000002"
        "0x81000003"
      ];
      description = "TPM persistent object handles holding Vault unseal shares.";
    };
    pcrs = lib.mkOption {
      type = lib.types.str;
      default =
        if secureBootEnabled
        then "0,2,7"
        else "0,2";
      description = "PCRs used when sealing unseal shares to TPM (manual setup).";
    };
    vaultAddr = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8200";
      description = "Vault address used by the unseal service.";
    };
    tcti = lib.mkOption {
      type = lib.types.str;
      default = "device:/dev/tpmrm0";
      description = "TCTI string used by tpm2-tools (e.g. device:/dev/tpmrm0 or device:/dev/tpm0).";
    };
    waitSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds to wait for Vault to become responsive before unsealing.";
    };
    restartOnFailure = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restart the unseal service if it fails (e.g. Vault not ready yet).";
    };
    restartSec = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Delay in seconds before retrying the unseal service.";
    };
  };

  config = {
    services.vault = {
      enable = true;
      package = pkgs.vault-bin;
      address = "[::]:8200";
      storageBackend = "raft";
      storageConfig = ''
        node_id = "${hostname}"
      '';
      extraConfig = ''
        ui = true
        disable_mlock = true
        api_addr = "http://${hostname}:8200"
        cluster_addr = "http://${hostname}:8201"
      '';
    };

    # Disable auto-unseal by default
    services.vault.tpmUnseal.enable = lib.mkDefault false;
    security.tpm2.enable = lib.mkIf tpmUnseal.enable (lib.mkDefault true);
    users.users.vault.extraGroups = lib.mkIf tpmUnseal.enable (lib.mkAfter ["tss"]);

    environment.systemPackages = lib.mkIf tpmUnseal.enable [
      pkgs.tpm2-tools
      pkgs.vault
    ];

    assertions = [
      {
        assertion = (!tpmUnseal.enable) || (tpmUnseal.handles != []);
        message = "services.vault.tpmUnseal.enable is true but no TPM handles are configured.";
      }
    ];

    systemd.services.vault-unseal = lib.mkIf tpmUnseal.enable {
      description = "Unseal Vault via TPM2";
      after = [
        "vault.service"
        "systemd-udevd.service"
        "tpm2-udev-trigger.service"
        "network-online.target"
      ];
      wants = [
        "vault.service"
        "tpm2-udev-trigger.service"
        "network-online.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "vault";
        Group = "vault";
        Environment = [
          "VAULT_ADDR=${tpmUnseal.vaultAddr}"
          "TPM2TOOLS_TCTI=${tpmUnseal.tcti}"
        ];
        ExecStartPre = [
          "${pkgs.bash}/bin/bash -lc 'for i in $(${pkgs.coreutils}/bin/seq 1 ${toString tpmUnseal.waitSeconds}); do ${pkgs.curl}/bin/curl -sS --connect-timeout 1 \"${tpmUnseal.vaultAddr}/v1/sys/health\" >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'"
        ];
        ExecStart = [
          "${unsealScript}"
        ];
        TimeoutStartSec = tpmUnseal.waitSeconds + 30;
        Restart = lib.mkIf tpmUnseal.restartOnFailure "on-failure";
        RestartSec = lib.mkIf tpmUnseal.restartOnFailure tpmUnseal.restartSec;
        RuntimeDirectory = "vault-unseal";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/run"];
      };
      wantedBy = ["multi-user.target"];
    };

    # Manual setup for TPM-bound unseal shares (OSS):
    # 1) Choose PCRs. When Secure Boot is enabled, use ${tpmUnseal.pcrs}
    #    (default: 0,2,7). Without Secure Boot, prefer a smaller PCR set.
    # 2) Create PCR policy: tpm2_createpolicy --policy-pcr -l sha256:${tpmUnseal.pcrs} -L /var/lib/vault/pcr.policy
    # 3) Create a primary key: tpm2_createprimary -C o -c /var/lib/vault/tpm.primary
    # 4) For each unseal share, seal and persist it to a handle in services.vault.tpmUnseal.handles:
    #    tpm2_create -C /var/lib/vault/tpm.primary -u /var/lib/vault/unsealX.pub -r /var/lib/vault/unsealX.priv \
    #      -L /var/lib/vault/pcr.policy -i /path/to/unseal_share_X
    #    tpm2_load -C /var/lib/vault/tpm.primary -u /var/lib/vault/unsealX.pub -r /var/lib/vault/unsealX.priv -c /var/lib/vault/unsealX.ctx
    #    tpm2_evictcontrol -C o -c /var/lib/vault/unsealX.ctx 0x8100000X
    # 5) Remove plaintext unseal share files after verifying a successful unseal.
  };
}
