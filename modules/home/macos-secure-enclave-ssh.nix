# Secure Enclave-backed SSH identity.
#
# The private key is generated inside the Secure Enclave and never leaves it,
# so this cannot replace the on-disk ~/.ssh/id_ed25519 that sops derives its
# age key from: `age.sshKeyPaths` has to read a file. It replaces that key for
# SSH authentication instead.
#
# OpenSSH reaches the enclave through /usr/lib/ssh-keychain.dylib acting as a
# SecurityKeyProvider (the FIDO2 interface, not PKCS#11 -- the latter only
# exposes smartcards, so PKCS11Provider returns no slots here). The provider
# needs a "stub" key file, which `ssh-keygen -K` exports from the resident CTK
# identity. The stub holds only the credential id; signing happens in the
# enclave, and Touch ID is required when the identity was created with `-t bio`.
#
# The CTK identity is machine state rather than a file, so it can only be
# created imperatively. Activation is the right place: nix-darwin runs
# home-manager under `launchctl asuser`, so sc_auth sees the user's session and
# Touch ID works. `ssh-keygen -K` may show a one-time Touch ID prompt on the
# first switch that exports the stub.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.macosSecureEnclaveSsh;
  protection =
    if cfg.biometric
    then "bio"
    else "none";
in {
  options.services.macosSecureEnclaveSsh = {
    enable = lib.mkEnableOption "a Secure Enclave-backed SSH identity";

    label = lib.mkOption {
      type = lib.types.str;
      description = "CTK identity label, as shown by `sc_auth list-ctk-identities`.";
    };

    biometric = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require Touch ID every time the key signs.";
    };

    identityFile = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${config.home.homeDirectory}/.ssh/id_ecdsa_sk_rk";
      description = "OpenSSH stub exported from the enclave, for use as `IdentityFile`.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The identity lives in the Secure Enclave, not in the store, so it cannot
    # be declared -- only ensured. Everything here is idempotent: the key is
    # created only when the label is missing, and the stub is re-exported only
    # when its fingerprint stops matching the identity (recreated or expired).
    home.activation.macosSecureEnclaveSsh = lib.hm.dag.entryAfter ["writeBoundary"] ''
      label=${lib.escapeShellArg cfg.label}
      stub=${lib.escapeShellArg cfg.identityFile}

      # macOS 26 moved sc_auth from /usr/bin to /usr/sbin. Look in both so a
      # system upgrade cannot turn this step into a bare "command not found"
      # (exit 127) that aborts the whole activation.
      if [ -x /usr/sbin/sc_auth ]; then
        sc_auth=/usr/sbin/sc_auth
      else
        sc_auth=/usr/bin/sc_auth
      fi

      # Every lookup below tolerates failure. Home Manager sources this snippet
      # into a `set -eu -o pipefail` script, so one non-zero command
      # substitution aborts the entire switch -- even though there is nothing
      # here that must be fatal.
      list_hashes() {
        "$sc_auth" list-ctk-identities -t "$1" 2>/dev/null \
          | /usr/bin/awk -v label="$label" 'NR > 1 && $4 == label { print $2; exit }' \
          || true
      }

      if [[ -v DRY_RUN ]]; then
        echo "would ensure Secure Enclave SSH identity $label"
      elif [ ! -x "$sc_auth" ]; then
        warnEcho "sc_auth not found; cannot ensure Secure Enclave SSH identity $label"
      else
        mkdir -p "$(dirname "$stub")"
        ctkHash="$(list_hashes sha1)"

        if [ -z "$ctkHash" ]; then
          if "$sc_auth" create-ctk-identity -l "$label" -k p-256-ne \
            -t ${protection} -N "$label" >/dev/null; then
            ctkHash="$(list_hashes sha1)"
          else
            warnEcho "could not create Secure Enclave SSH identity $label"
          fi
        fi

        wantFp="$(list_hashes ssh)"
        # `ssh-keygen -lf` exits 255 when the stub has not been exported yet
        # (the normal first-switch case), which pipefail would turn into a
        # failed activation before the export below ever runs.
        haveFp="$(/usr/bin/ssh-keygen -lf "$stub.pub" 2>/dev/null \
          | /usr/bin/awk '{ print $2 }' || true)"

        # Fingerprints are compared rather than file mtimes because CTK
        # identities expire after a year; a recreated identity reuses nothing.
        if [ -n "$ctkHash" ] && [ "$wantFp" != "$haveFp" ]; then
          tmp="$(/usr/bin/mktemp -d)"

          if (cd "$tmp" && KEYCHAIN_CERTIFICATES="$ctkHash" \
            SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib \
            /usr/bin/ssh-keygen -w /usr/lib/ssh-keychain.dylib -K -N "" >/dev/null 2>&1); then
            if ! { /usr/bin/install -m 600 "$tmp/id_ecdsa_sk_rk" "$stub" \
              && /usr/bin/install -m 644 "$tmp/id_ecdsa_sk_rk.pub" "$stub.pub"; }; then
              warnEcho "could not install the Secure Enclave public key for $label"
            fi
          else
            warnEcho "could not export the Secure Enclave public key for $label"
          fi

          /bin/rm -rf "$tmp"
        fi
      fi
    '';
  };
}
