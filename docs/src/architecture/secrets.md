# Secrets Management

Secrets are managed through two complementary systems: **sops-nix** for at-rest encryption and **vault-secrets** for runtime credential injection.

## sops-nix

Encrypted YAML files in `secrets/` are decrypted at system activation. Each host has its own secrets file, plus a shared `global.yaml`.

```
secrets/
  global.yaml        # Shared across all hosts (e.g., U2F keys)
  endeavour.yaml     # Per-host secrets
  enterprise.yaml
  ...
```

Encryption keys are configured in `.sops.yaml`:
- Each host has two age keys (host key + user key)
- A PGP admin key can decrypt everything
- Per-host files are only decryptable by that host's keys

## vault-secrets

Services that need credentials declare them through `vault-secrets.secrets`:

```nix
vault-secrets.secrets.my-service = {
  services = ["my-service"];
};
```

This triggers a chain:

1. sops-nix decrypts the Vault approle credentials at boot (`secrets/approles/<name>`)
2. The `<name>-secrets` systemd service uses the approle to fetch secrets from Vault
3. Secrets are written to `/run/secrets/<name>/`
4. The target service's `EnvironmentFile` is set to load them

The wiring between sops-nix and vault-secrets happens automatically in `hosts/shared/nixos-common.nix`.

## Vault address

The Vault server address is configured via `machines.vault.address` (default: `http://endeavour:8200`). Override this if your Vault is elsewhere:

```nix
machines.vault.address = "https://vault.example.com:8200";
```
