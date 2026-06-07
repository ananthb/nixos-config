# Seafile Podman container definitions (quadlet).
{
  config,
  containerImages,
  lib,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
  seafileHostname = "seafile.kedi.dev";

  # --- Configuration files ---

  seahubSettings = pkgs.writeText "seahub_settings.py" ''
    TIME_ZONE = "${config.time.timeZone}"

    CSRF_TRUSTED_ORIGINS = ["https://seafile.kedi.dev", "http://endeavour.local:4000"]
    USE_X_FORWARDED_HOST = True
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

    # OAuth Setup
    ENABLE_OAUTH = True
    OAUTH_CREATE_UNKNOWN_USER = True
    OAUTH_ACTIVATE_USER_AFTER_CREATION = False
    OAUTH_REDIRECT_URL = "https://seafile.kedi.dev/oauth/callback/"
    OAUTH_PROVIDER_DOMAIN = "google.com"
    OAUTH_AUTHORIZATION_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    OAUTH_TOKEN_URL = "https://www.googleapis.com/oauth2/v4/token"
    OAUTH_USER_INFO_URL = "https://www.googleapis.com/oauth2/v1/userinfo"
    OAUTH_SCOPE = [
        "openid",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ]
    OAUTH_ATTRIBUTE_MAP = {
        "id": (True, "uid"),
        "name": (False, "name"),
        "email": (False, "contact_email"),
    }

    # SMTP
    EMAIL_USE_TLS = True
    EMAIL_HOST = "smtp.tem.scw.cloud"
    EMAIL_PORT = 25
    DEFAULT_FROM_EMAIL = "seafile@kedi.dev"
    SERVER_EMAIL = DEFAULT_FROM_EMAIL

    # Enable metadata server
    ENABLE_METADATA_MANAGEMENT = True
    METADATA_SERVER_URL = "http://seafile-md-server:8084"

    # Collabora Code
    OFFICE_SERVER_TYPE = "CollaboraOffice"
    ENABLE_OFFICE_WEB_APP = True
    OFFICE_WEB_APP_BASE_URL = "http://collabora-code:9980/collabora-code/hosting/discovery"

    WOPI_ACCESS_TOKEN_EXPIRATION = 30 * 60  # seconds

    OFFICE_WEB_APP_FILE_EXTENSION = (
        "odp", "ods", "odt", "xls", "xlsb", "xlsm", "xlsx",
        "ppsx", "ppt", "pptm", "pptx", "doc", "docm", "docx",
    )

    ENABLE_OFFICE_WEB_APP_EDIT = True

    OFFICE_WEB_APP_EDIT_FILE_EXTENSION = (
        "odp", "ods", "odt", "xls", "xlsb", "xlsm", "xlsx",
        "ppsx", "ppt", "pptm", "pptx", "doc", "docm", "docx",
    )
  '';

  seafileConf = pkgs.writeText "seafile.conf" ''
    [fileserver]
    port=8082
    max_download_dir_size=10000

    [notification]
    enabled = true
    host = 127.0.0.1
    port = 8083
  '';

  # Common MySQL env vars shared across containers
  mysqlEnv = ''
    SEAFILE_MYSQL_DB_HOST=host.containers.internal
    SEAFILE_MYSQL_DB_USER=seafile
    SEAFILE_MYSQL_DB_PORT=3306
  '';

  seafileEnv = pkgs.writeText "seafile.env" ''
    # initial variables (valid only during first-time init)
    INIT_SEAFILE_ADMIN_EMAIL=admin@example.com

    # startup parameters
    SEAFILE_LOG_TO_STDOUT=true
    SEAFILE_SERVER_HOSTNAME=${seafileHostname}
    SEAFILE_SERVER_PROTOCOL=https
    TIME_ZONE=${config.time.timeZone}
    NON_ROOT=false

    # database
    ${mysqlEnv}
    SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
    SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
    SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

    # redis
    CACHE_PROVIDER=redis
    REDIS_HOST=host.containers.internal
    REDIS_PORT=6400

    # seadoc
    ENABLE_SEADOC=true
    SEADOC_SERVER_URL=https://${seafileHostname}/sdoc-server

    # metadata server
    MD_FILE_COUNT_LIMIT=100000

    # notification server
    ENABLE_NOTIFICATION_SERVER=true
    INNER_NOTIFICATION_SERVER_URL=http://seafile-notification-server:8083
    NOTIFICATION_SERVER_URL=https://${seafileHostname}/notification

    # ai server
    ENABLE_SEAFILE_AI=true
    SEAFILE_AI_SERVER_URL=http://seafile-ai:8888
  '';

  notificationServerEnv = pkgs.writeText "seafile-notification-server.env" ''
    ${mysqlEnv}
    SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
    SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
    SEAFILE_LOG_TO_STDOUT=true
    NOTIFICATION_SERVER_LOG_LEVEL=info
  '';

  mdServerEnv = pkgs.writeText "seafile-md-server.env" ''
    ${mysqlEnv}
    SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
    SEAFILE_LOG_TO_STDOUT=true
    MD_PORT=8084
    MD_LOG_LEVEL=info
    MD_MAX_CACHE_SIZE=1GB
    MD_CHECK_UPDATE_INTERVAL=30m
    MD_FILE_COUNT_LIMIT=100000
    SEAF_SERVER_STORAGE_TYPE=disk
    MD_STORAGE_TYPE=disk
    CACHE_PROVIDER=redis
    REDIS_HOST=host.containers.internal
    REDIS_PORT=6400
  '';

  thumbnailServerEnv = pkgs.writeText "seafile-thumbnail-server.env" ''
    TIME_ZONE=${config.time.timeZone}
    ${mysqlEnv}
    SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
    SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
    INNER_SEAHUB_SERVICE_URL=http://seafile
    THUMBNAIL_IMAGE_ORIGINAL_SIZE_LIMIT=256
    SEAF_SERVER_STORAGE_TYPE=disk
  '';

  aiEnv = pkgs.writeText "seafile-ai.env" ''
    SEAFILE_AI_LLM_TYPE=openai
    SEAFILE_AI_LLM_URL=http://enterprise:11434/v1
    SEAFILE_AI_LLM_MODEL=gemma3:12b
    SEAFILE_SERVER_URL=http://seafile
    SEAFILE_AI_LOG_LEVEL=info
    CACHE_PROVIDER=redis
    REDIS_HOST=host.containers.internal
    REDIS_PORT=6400
  '';

  seadocEnv = pkgs.writeText "seadoc.env" ''
    SEAFILE_SERVER_HOSTNAME=${seafileHostname}
    SEAFILE_SERVER_PROTOCOL=https
    TIME_ZONE=${config.time.timeZone}
    SEAHUB_SERVICE_URL=http://seafile
    DB_HOST=host.containers.internal
    DB_USER=seafile
    DB_PORT=3306
    DB_NAME=sdoc_db
    NON_ROOT=false
  '';

  # --- Helpers ---

  seafileNetwork = config.virtualisation.quadlet.networks.seafile.ref;

  mkSeafileDeps = {
    after,
    wants ? after,
  }: {
    serviceConfig.Restart = "on-failure";
    unitConfig = {
      RequiresMountsFor = "/srv";
      After = lib.concatStringsSep " " after;
      Wants = lib.concatStringsSep " " wants;
    };
  };
in {
  virtualisation.quadlet = {
    autoEscape = true;
    autoUpdate.enable = true;

    networks.seafile.networkConfig.interfaceName = "podman-seafile";

    containers = {
      seafile = {
        containerConfig = {
          name = "seafile";
          image = containerImages.seafile;
          autoUpdate = "registry";
          volumes = ["/srv/seafile/seafile-server:/shared"];
          networks = [seafileNetwork];
          publishPorts = ["4450:80"];
          environmentFiles = [
            "${seafileEnv}"
            "${vs.seafile}/seafile.env"
          ];
        };
        serviceConfig = {
          Restart = "on-failure";
          ExecStartPre = [
            "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/cat ${vs.seafile}/seahub_settings.enc.py ${seahubSettings} > /srv/seafile/seafile-server/seafile/conf/seahub_settings.py'"
            "${pkgs.coreutils}/bin/cp ${seafileConf} /srv/seafile/seafile-server/seafile/conf/seafile.conf"
          ];
        };
        unitConfig = {
          Before = "caddy.service";
          RequiresMountsFor = "/srv";
          After = lib.concatStringsSep " " [
            "mysql.service"
            "redis-seafile.service"
            "seadoc.service"
            "seafile-ai.service"
            "seafile-md-server.service"
            "seafile-notification-server.service"
            "seafile-thumbnail-server.service"
          ];
          Wants = lib.concatStringsSep " " [
            "caddy.service"
            "mysql.service"
            "redis-seafile.service"
            "seadoc.service"
            "seafile-ai.service"
            "seafile-md-server.service"
            "seafile-notification-server.service"
            "seafile-thumbnail-server.service"
          ];
        };
      };

      seafile-notification-server =
        lib.recursiveUpdate (mkSeafileDeps {
          after = ["mysql.service"];
          wants = ["mysql.service" "caddy.service"];
        }) {
          containerConfig = {
            name = "seafile-notification-server";
            image = containerImages.seafileNotification;
            autoUpdate = "registry";
            networks = [seafileNetwork];
            publishPorts = ["8083:8083"];
            environmentFiles = [
              "${notificationServerEnv}"
              "${vs.seafile}/notification-server.env"
            ];
          };
          unitConfig.Before = "caddy.service";
        };

      seafile-md-server =
        lib.recursiveUpdate (mkSeafileDeps {
          after = ["mysql.service" "redis-seafile.service"];
          wants = ["caddy.service" "mysql.service" "redis-seafile.service"];
        }) {
          containerConfig = {
            name = "seafile-md-server";
            image = containerImages.seafileMd;
            autoUpdate = "registry";
            volumes = ["/srv/seafile/seafile-server:/shared"];
            networks = [seafileNetwork];
            publishPorts = ["8084:8084"];
            environmentFiles = [
              "${mdServerEnv}"
              "${vs.seafile}/md-server.env"
            ];
          };
          unitConfig.Before = "caddy.service";
        };

      seafile-thumbnail-server =
        lib.recursiveUpdate (mkSeafileDeps {
          after = ["mysql.service"];
          wants = ["mysql.service" "caddy.service"];
        }) {
          containerConfig = {
            name = "seafile-thumbnail-server";
            image = containerImages.seafileThumbnail;
            autoUpdate = "registry";
            volumes = ["/srv/seafile/seafile-server:/shared"];
            networks = [seafileNetwork];
            publishPorts = ["4453:80"];
            environmentFiles = [
              "${thumbnailServerEnv}"
              "${vs.seafile}/thumbnail-server.env"
            ];
          };
          unitConfig.Before = "caddy.service";
        };

      seafile-ai =
        lib.recursiveUpdate (mkSeafileDeps {
          after = ["redis-seafile.service"];
        }) {
          containerConfig = {
            name = "seafile-ai";
            image = containerImages.seafileAi;
            autoUpdate = "registry";
            volumes = ["/srv/seafile/seafile-server:/shared"];
            networks = [seafileNetwork];
            environmentFiles = [
              "${aiEnv}"
              "${vs.seafile}/ai.env"
            ];
          };
        };

      seadoc = {
        containerConfig = {
          name = "seadoc";
          image = containerImages.seadoc;
          autoUpdate = "registry";
          volumes = ["/srv/seafile/seadoc:/shared"];
          networks = [seafileNetwork];
          publishPorts = ["4451:80"];
          environmentFiles = [
            "${seadocEnv}"
            "${vs.seafile}/seadoc.env"
          ];
        };
        serviceConfig.Restart = "on-failure";
        unitConfig.RequiresMountsFor = "/srv";
      };

      collabora-code = {
        containerConfig = {
          name = "collabora-code";
          image = containerImages.collabora;
          podmanArgs = ["--privileged"];
          autoUpdate = "registry";
          networks = [seafileNetwork];
          publishPorts = ["9980:9980"];
          environmentFiles = ["${vs.collabora}/code.env"];
          environments = {
            extra_params = lib.concatStringsSep " " [
              "--o:logging.file[@enable]=false"
              "--o:admin_console.enable=true"
              "--o:ssl.enable=false"
              "--o:ssl.termination=true"
              "--o:net.service_root=/collabora-code"
            ];
          };
        };
        serviceConfig.Restart = "on-failure";
        unitConfig.RequiresMountsFor = "/srv";
      };
    };
  };
}
