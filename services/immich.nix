{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: let
  vs = config.vault-secrets.secrets;
  immichHostname = "immich.kedi.dev";
in {
  imports = [
    ./gcloud-oauth.nix
    ./monitoring/postgres.nix
  ];

  services.immich = {
    enable = true;
    machine-learning.enable = false;
    host = "::";
    openFirewall = true;
    environment = {
      "IMMICH_TRUSTED_PROXIES" = "::1,127.0.0.0/8";
      "IMMICH_TELEMETRY_INCLUDE" = "all";
    };
    settings = {
      ffmpeg = {
        crf = 23;
        threads = 0;
        preset = "ultrafast";
        targetVideoCodec = "h264";
        acceptedVideoCodecs = ["h264"];
        targetAudioCodec = "aac";
        acceptedAudioCodecs = [
          "aac"
          "mp3"
          "libopus"
          "pcm_s16le"
        ];
        acceptedContainers = [
          "mov"
          "ogg"
          "webm"
        ];
        targetResolution = "720";
        maxBitrate = "0";
        bframes = -1;
        refs = 0;
        gopSize = 0;
        temporalAQ = false;
        cqMode = "auto";
        twoPass = false;
        preferredHwDevice = "auto";
        transcode = "required";
        tonemap = "hable";
        accel = "qsv";
        accelDecode = true;
      };
      backup.database = {
        enabled = true;
        cronExpression = "50 * * * *";
        keepLastAmount = 3;
      };
      job = {
        backgroundTask.concurrency = 4;
        smartSearch.concurrency = 8;
        metadataExtraction.concurrency = 4;
        faceDetection.concurrency = 4;
        search.concurrency = 4;
        sidecar.concurrency = 4;
        library.concurrency = 4;
        migration.concurrency = 4;
        thumbnailGeneration.concurrency = 8;
        videoConversion.concurrency = 4;
        notifications.concurrency = 4;
      };
      logging = {
        enabled = true;
        level = "log";
      };
      machineLearning = {
        enabled = true;
        urls =
          (builtins.map (host: "http://${host}:3003") outputs.lib.immichMlHosts)
          ++ (lib.optional (config.services.immich.machine-learning.enable or false) "http://localhost:3003");
        clip = {
          enabled = true;
          modelName = "ViT-B-32__openai";
        };
        duplicateDetection = {
          enabled = true;
          maxDistance = 0.01;
        };
        facialRecognition = {
          enabled = true;
          modelName = "buffalo_l";
          minScore = 0.7;
          maxDistance = 0.5;
          minFaces = 20;
        };
      };
      map = {
        enabled = true;
        lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
        darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
      };
      reverseGeocoding.enabled = true;
      metadata.faces.import = true;
      oauth = {
        autoLaunch = false;
        autoRegister = true;
        buttonText = "Sign in with Google";
        clientId._secret = "${vs.gcloud-oauth}/client_id";
        clientSecret._secret = "${vs.gcloud-oauth}/client_secret";
        defaultStorageQuota = null;
        enabled = true;
        issuerUrl = "https://accounts.google.com/.well-known/openid-configuration";
        mobileOverrideEnabled = true;
        mobileRedirectUri = "https://${immichHostname}/api/oauth/mobile-redirect";
        scope = "openid email profile";
        signingAlgorithm = "RS256";
        profileSigningAlgorithm = "none";
        storageLabelClaim = "preferred_username";
        storageQuotaClaim = "immich_quota";
      };
      passwordLogin.enabled = false;
      storageTemplate = {
        enabled = false;
        hashVerificationEnabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
      image = {
        thumbnail = {
          format = "webp";
          size = 250;
          quality = 80;
        };
        preview = {
          format = "jpeg";
          size = 1440;
          quality = 80;
        };
        colorspace = "p3";
        extractEmbedded = true;
      };
      newVersionCheck.enabled = false;
      trash = {
        enabled = true;
        days = 30;
      };
      theme.customCss = "";
      library = {
        scan = {
          enabled = true;
          cronExpression = "0 0 * * *";
        };
        watch.enabled = false;
      };
      server = {
        externalDomain = "https://${immichHostname}";
        loginPageMessage = "Welcome to KEDI Immich server";
        publicUsers = true;
      };
      notifications.smtp = {
        enabled = false;
        from = "immich@kedi.dev";
        replyTo = "immich@kedi.dev";
        transport = {
          ignoreCert = false;
          host = "smtp.tem.scw.cloud";
          port = 587;
          username._secret = "${vs.immich}/smtp_username";
          password._secret = "${vs.immich}/smtp_password";
        };
      };
      user.deleteDelay = 7;
    };
    accelerationDevices = ["/dev/dri/renderD128"];
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];

  my-services.kediTargets.immich-server = true;

  systemd.services.immich-server.serviceConfig.SupplementaryGroups = ["gcloud-oauth"];

  systemd.services.immich-backup = {
    # TODO: re-enable after we've trimmed down unnecessary files
    # startAt = "weekly";
    environment.KOPIA_CHECK_FOR_UPDATES = "false";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${config.my-scripts.kopia-snapshot-backup} /srv/immich";
    };
    path = [pkgs.bcachefs-tools pkgs.btrfs-progs pkgs.coreutils pkgs.curl pkgs.kopia];
  };

  vault-secrets.secrets.immich = {
    services = [
      "immich-server"
      "immich-microservices"
    ];
    inherit (config.services.immich) group;
  };
}
