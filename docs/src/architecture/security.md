# Security

## Secure Boot

x86_64 hosts use Lanzaboote for UEFI Secure Boot with signed Unified Kernel Images. Keys are managed with `sbctl` from `/var/lib/sbctl`. Systemd initrd is enabled for early boot TPM operations.

## Vault with TPM auto-unseal

HashiCorp Vault stores all service credentials. On hosts with a TPM2, Vault auto-unseals at boot:

1. Three unseal key shares are sealed to TPM persistent handles (`0x81000001`-`0x81000003`)
2. Each share is bound to PCR values (0, 2, 7 with Secure Boot; 0, 2 without)
3. At boot, a systemd service decrypts all three shares from the TPM and sends them to Vault's unseal API
4. The service waits up to 5 minutes for Vault to become healthy before attempting unseal

This means Vault is fully operational within seconds of boot with no manual intervention.

## Authentication

- **sudo is disabled**. Privilege escalation uses `run0` (systemd) with polkit rules granting wheel group members passwordless access.
- **SSH** is key-only (no passwords, no root login). Authorized keys are Yubikey-resident ED25519 keys.
- **U2F/FIDO2** is enabled for PAM login and SSH authentication.
- **Yubikey** support includes PCSCD and udev rules for personalization.

## Systemd hardening

- **systemd-oomd** monitors memory pressure across root, user, and system slices. Kills low-priority services before the kernel OOM killer fires.
- **Emergency mode is disabled** to prevent boot-time interactive shells on servers.
- **Journal limits** cap persistent logs at 500MB and runtime logs at 100MB.
- **Kernel panic settings** auto-reboot after 10 seconds on panic and panic on oops.

## Network

- **Firewall** is enabled by default with ICMP allowed.
- **Tailscale interface is trusted** so Tailscale ACLs govern access rather than per-port firewall rules.
- **Services are not exposed via `openFirewall`**. All service access goes through Tailscale or Cloudflare Tunnels.
