# Shared Google OAuth client credentials from Vault.
# Vault path: kv/services/gcloud-oauth
# Expected keys: client_id, client_secret
#
# Services that need Google login import this module and reference
# the files at ${config.vault-secrets.secrets.gcloud-oauth}/client_id
# and ${config.vault-secrets.secrets.gcloud-oauth}/client_secret.
_: {
  vault-secrets.secrets.gcloud-oauth = {
    services = ["immich-server"];
    group = "gcloud-oauth";
  };

  users.groups.gcloud-oauth = {};
}
