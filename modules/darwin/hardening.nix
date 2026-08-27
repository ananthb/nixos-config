{
  config,
  lib,
  ...
}: let
  cfg = config.machines;
  nodeExporter = config.services.prometheus.exporters.node;
  nodeExporterBin = "${nodeExporter.package}/bin/node_exporter";
in {
  # Baseline endpoint hardening for darwin hosts. FileVault, SIP and
  # Gatekeeper are enabled out of band (they can't be flipped from a
  # config file); everything declarable lives here.

  networking.applicationFirewall = {
    enable = true;
    # Signed Apple and Developer-ID binaries still accept incoming
    # connections without prompting; anything else has to be allowlisted
    # explicitly (see postActivation below).
    allowSigned = true;
    allowSignedApp = true;
    # Drop unsolicited probes (ICMP echo, closed-port TCP RST) instead of
    # answering them. This also silences `ping discovery.local` from the
    # homelab — flip it off if that breaks a diagnostic you rely on.
    enableStealthMode = true;
  };

  system.defaults = {
    screensaver = {
      # Lock as soon as the screen sleeps. displaysleep is 2 minutes, so
      # a walked-away-from laptop is locked in about that long.
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    loginwindow = {
      GuestEnabled = false;
      # Show a name/password prompt rather than a clickable list of
      # accounts, so the login screen doesn't enumerate valid usernames.
      SHOWFULLNAME = true;
      # Block the >console escape hatch at the login window.
      DisableConsoleAccess = true;
    };

    # Keep the quarantine bit and its "downloaded from the internet"
    # prompt on. Declared rather than left at the default so a stray
    # `defaults write` can't silently turn it off.
    LaunchServices.LSQuarantine = true;

    # Full extensions everywhere: a `.pdf.app` masquerading as a document
    # is only obvious when the real extension is visible.
    NSGlobalDomain.AppleShowAllExtensions = true;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
  };

  # Runs after the firewall block above has been applied.
  system.activationScripts.postActivation.text = ''
    fw=/usr/libexec/ApplicationFirewall/socketfilterfw

    ${lib.optionalString nodeExporter.enable ''
      # node_exporter is an unsigned Nix binary, so allowSigned doesn't cover
      # it and the firewall would drop Prometheus scrapes over Tailscale.
      # Allowlist the exact store path being activated. socketfilterfw exits
      # non-zero on a re-add, which `set -e` would treat as a failed switch.
      "$fw" --add ${lib.escapeShellArg nodeExporterBin} >/dev/null || true
      "$fw" --unblockapp ${lib.escapeShellArg nodeExporterBin} >/dev/null || true
    ''}

    # Log denied connections so there's a trail to read after the fact:
    #   sudo cat /var/log/appfirewall.log
    "$fw" --setloggingmode on >/dev/null || true
    "$fw" --setloggingopt detail >/dev/null || true

    # AirPlay Receiver listens on :5000 and :7000 for anything that can
    # reach this host on the local network. Off unless it's actually in use.
    # It lives in a -currentHost domain that system.defaults can't write,
    # and activation now runs entirely as root, so drop back to the user.
    sudo -u ${lib.escapeShellArg cfg.username} /usr/bin/defaults -currentHost \
      write com.apple.controlcenter AirplayRecieverEnabled -bool false || true
  '';
}
