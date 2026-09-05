# Vault, as a client of the pwu cluster rather than a server on this box.
#
# The machines-side config runs a self-hosted single-node Vault here: raft
# storage in /var/lib/vault, a shamir seal, three unseal shares sealed to TPM
# handles, and vault-secrets pulling every service credential out of it over
# loopback. That Vault is the reason this host is load-bearing in a way a
# compute node should not be -- it holds secrets nothing else can serve, its
# raft peer id is baked into its own storage, and it has to be unsealed before
# anything else on the box can start.
#
# pwu-compute3 does not run it. It authenticates to the cluster Vault at the
# tailnet VIP and lets vault-agent render what it needs, exactly the way the
# camera nodes do (calculon-tech/platform, debian/picam/overlay/etc/vault-agent).
# That is what makes this a node the cluster owns rather than a pet.
#
# Two files stay imperative, and only two: role-id and secret-id. They are the
# AppRole credentials, they are not in git, and they are placed once by hand --
# see doc/node-tls-renewal.md in the platform repo. Everything else, including
# the CA, is rendered.
{
  config,
  lib,
  ...
}: let
  cfg = config.machines.vaultAgent;
in {
  options.machines.vaultAgent = {
    enable = lib.mkEnableOption "vault-agent against the pwu cluster Vault";

    address = lib.mkOption {
      type = lib.types.str;
      default = "https://vault.cow-justice.ts.net";
      description = ''
        The cluster Vault, reached over the tailnet. tag:infra is granted 443
        to the svc:vault VIP and nothing else
        (calculon-tech/platform, tf/tailscale/policy.hujson), so this host has
        to carry that tag before the agent can authenticate.
      '';
    };

    credentialsDir = lib.mkOption {
      type = lib.types.path;
      default = "/etc/vault-agent";
      description = ''
        Where role-id and secret-id live. Provisioned once by hand and never
        rotated by this config -- a secret_id that the node cannot re-read
        after a reboot is a node that never comes back.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.vault-agent.instances.node = {
      settings = {
        vault.address = cfg.address;

        auto_auth = {
          method = [
            {
              type = "approle";
              mount_path = "auth/approle";
              config = {
                role_id_file_path = "${cfg.credentialsDir}/role-id";
                secret_id_file_path = "${cfg.credentialsDir}/secret-id";
                # The secret_id is provisioned once and must survive restarts.
                # Consuming it on read would leave this host unable to
                # re-authenticate after a reboot, with no way in but a physical
                # trip -- there is no out-of-band access to this machine.
                remove_secret_id_file_after_reading = false;
              };
            }
          ];

          sink = [
            {
              type = "file";
              config = [{path = "/run/vault-agent/token";}];
            }
          ];
        };

        # This node boots without knowing whether Vault is up, sealed, or even
        # reachable. Keep retrying rather than exiting and leaving nobody
        # watching the certs.
        template_config.exit_on_retry_failure = false;

        # The CA chain, so a node that has never been bootstrapped needs
        # exactly the two AppRole files and nothing else copied in.
        #
        # The per-service leaves (consul.crt/key, nomad.crt/key) and the agent
        # secrets (gossip key, ACL tokens) are deliberately not here yet: they
        # arrive with the consul and nomad clients, in the change that makes
        # this host join the cluster. Rendering a Consul leaf onto a box with
        # no Consul only creates a file that nothing reloads and nobody checks.
        template = [
          {
            contents = ''
              {{- with secret "pki_int/cert/ca_chain" -}}
              {{ .Data.certificate }}
              {{- end }}
            '';
            destination = "/etc/pki/pwu-ca.pem";
            perms = "0644";
          }
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.credentialsDir} 0700 root root -"
      "d /etc/pki 0755 root root -"
    ];
  };
}
