# NixOS guest for a Coder dev workspace, booted as a systemd PID-1 guest under
# kata / cloud-hypervisor (the Nomad containerd driver uses the built OCI image
# as the guest rootfs; kata supplies the kernel). The Coder agent runs as a
# systemd service that reads CODER_AGENT_URL / CODER_AGENT_TOKEN from the
# container environment injected by the Nomad jobspec, so no per-workspace init
# script is baked into the image. The dev environment is the same home/coder.nix
# profile used by homeConfigurations."coder@x86_64-linux".
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # The Coder web terminal draws in the browser, so the glyphs come from the
  # font on whatever machine that browser runs on -- a Chromebook, here. A font
  # installed in this guest can never reach that rasterizer, and Coder's own
  # terminal font setting is a closed enum of five faces
  # (codersdk.TerminalFontName), none of them patched. So the only way a Nerd
  # Font glyph renders is if the page carries the font itself.
  #
  # woff2 rather than the .ttf: 2.7M -> 1.2M, and it is inlined as base64 into
  # a single HTML file, so that difference is the page weight. Regular only --
  # bold is left to the browser to synthesise, because a second face would add
  # another ~1.6M of base64 to buy a slightly better bold.
  hackNerdWoff2 =
    pkgs.runCommand "hack-nerd-font-mono.woff2" {
      nativeBuildInputs = [pkgs.woff2];
    } ''
      cp ${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/HackNerdFontMono-Regular.ttf font.ttf
      woff2_compress font.ttf
      mv font.woff2 $out
    '';

  # The <style> block is built here, at eval time, so the 1.6M base64 string is
  # written once into the store instead of being re-encoded on every boot.
  ttydFontStyle = pkgs.runCommand "ttyd-font-style.html" {} ''
    {
      printf "%s" "<style>@font-face{font-family:'Hack Nerd Font Mono';font-style:normal;font-weight:400;font-display:block;src:url(data:font/woff2;base64,"
      ${pkgs.coreutils}/bin/base64 -w0 ${hackNerdWoff2}
      printf "%s" ") format('woff2');}</style>"
    } > $out
  '';

  # Orca (onorca.dev), the agent orchestrator, from numtide's llm-agents.nix:
  # upstream's .deb, patchelf'd. orca-serve.service below runs it headless.
  # Through the overlay, applied by hand because nixpkgs.pkgs is pinned here:
  # the flake's `packages` filters every package by availability, and a
  # sibling wants an electron our nixpkgs does not carry.
  orca = (inputs.llm-agents.overlays.shared-nixpkgs pkgs pkgs).llm-agents.orca;

  # Joins the tailnet. Two callers: tailscale-up at boot with the baseline key
  # off PID 1, and ws-escalate with the trusted key from Vault. TS_AUTHKEY and
  # TS_HOSTNAME come from the environment; --key-stdin reads the key from
  # stdin so it never lands in argv.
  #
  # --hostname: networking.hostName is "coder" for every workspace; the
  # jobspec passes ws-<owner>-<workspace>.
  # --accept-dns: tailscaled takes over /etc/resolv.conf and forwards
  # non-tailnet names to the resolver the runtime wrote. Verified on a live
  # workspace; needs the real TUN, userspace mode would black-hole lookups.
  # --force-reauth: a second run re-registers instead of no-op'ing. Same
  # machine key, so the tailnet sees the same node with the new key's tags.
  tailscaleJoin = pkgs.writeShellScript "tailscale-join" ''
    set -eu
    if [ "''${1:-}" = --key-stdin ]; then
      TS_AUTHKEY="$(cat)"
    fi
    # No key is not an error: the image must still boot into a usable
    # workspace on a template version that predates TS_AUTHKEY, and on a
    # bare `docker run` of it done by hand for debugging.
    if [ -z "''${TS_AUTHKEY:-}" ]; then
      echo "tailscale-join: TS_AUTHKEY is empty; staying logged out." >&2
      exit 0
    fi
    exec ${pkgs.tailscale}/bin/tailscale up \
      --auth-key="$TS_AUTHKEY" \
      --hostname="''${TS_HOSTNAME:-coder}" \
      --accept-dns=true \
      --accept-routes=false \
      --ssh \
      --force-reauth
  '';

  # Step up from tag:coder to tag:coder + tag:coder-trusted, or back down.
  # The trusted key lives in Vault under secret/ananth/, readable only by the
  # owner's OIDC role, so the wider reach costs a Google login as the owner.
  # The OIDC callback is localhost:8250 on the browser's machine: from a
  # laptop, `ssh -L 8250:localhost:8250 <node>` first. `down` re-runs the boot
  # join with the baseline key; so does a restart.
  wsEscalate = pkgs.writeShellApplication {
    name = "ws-escalate";
    runtimeInputs = [pkgs.jq pkgs.tailscale pkgs.vault-bin];
    text = ''
      mode="''${1:-up}"
      export VAULT_ADDR="''${VAULT_ADDR:-https://vault.cow-justice.ts.net}"
      self="$(tailscale status --self --json)"
      tags="$(jq -r '.Self.Tags // [] | join(",")' <<<"$self")"

      case "$mode" in
        up)
          if [[ "$tags" == *tag:coder-trusted* ]]; then
            echo "ws-escalate: already tag:coder-trusted ($tags)" >&2
            exit 0
          fi
          hostname="$(jq -r '.Self.HostName' <<<"$self")"
          echo "ws-escalate: log in to Vault as the owner. The link's callback is" >&2
          echo "ws-escalate: localhost:8250 on the browser's machine; from a laptop," >&2
          echo "ws-escalate: run  ssh -L 8250:localhost:8250 $hostname  first." >&2
          token="$(vault login -method=oidc -no-store -format=json \
            role=ananth skip_browser=true | jq -r .auth.client_token)"
          key="$(VAULT_TOKEN="$token" vault kv get -field=authkey \
            secret/ananth/coder/tailscale-trusted)"
          # The token was for one read; do not leave an hour of owner-daily
          # sitting in a box that runs unattended code.
          VAULT_TOKEN="$token" vault token revoke -self >/dev/null
          printf %s "$key" | sudo TS_HOSTNAME="$hostname" ${tailscaleJoin} --key-stdin
          ;;
        down)
          sudo systemctl restart tailscale-up.service
          ;;
        *)
          echo "usage: ws-escalate [up|down]" >&2
          exit 64
          ;;
      esac
      sleep 2
      echo "ws-escalate: now $(tailscale status --self --json | jq -r '.Self.Tags // [] | join(",")')" >&2
    '';
  };
in {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../modules/options.nix
    ../modules/nixos/nix-settings.nix
  ];

  # systemd as PID 1 with no bootloader/kernel — kata provides the kernel and
  # runs the image's init. Networking (address, DNS, egress) is set up by the
  # Nomad bridge/CNI on the guest NIC, so NixOS should not manage it.
  boot.isContainer = true;
  networking = {
    hostName = "coder";
    useDHCP = false;
    useHostResolvConf = lib.mkForce false;

    # The runtime writes /etc/resolv.conf into the container -- docker's own
    # for a plain `docker run`, Nomad's CNI for a workspace. NixOS's resolvconf
    # would overwrite it, and because useDHCP is false and no nameservers are
    # set here, what it writes contains no nameserver at all:
    #
    #   # Generated by resolvconf
    #   options edns0
    #
    # So every lookup in the guest failed and coder-agent.service sat in a
    # restart loop on `curl: (6) Could not resolve host: coder.calculon.tech`,
    # which presented as an agent that never connected. Leave the file alone.
    resolvconf.enable = false;
  };

  users.users.coder = {
    isNormalUser = true;
    home = "/home/coder";
    extraGroups = ["wheel"];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  environment.systemPackages = [pkgs.coder pkgs.curl pkgs.git pkgs.tailscale orca wsEscalate];

  # Reduce image size.
  documentation.enable = false;

  systemd = {
    # /dev in the kata guest is a plain tmpfs the runtime populates from the OCI
    # spec, not devtmpfs, so the tun node tailscaled wants is simply absent --
    # even though the guest kernel does carry the driver. Opening a hand-made
    # node returns EBADFD ("file descriptor in bad state"), not ENODEV, which is
    # how you tell those two apart. mknod needs CAP_MKNOD, which is already in
    # the container's bounding set.
    tmpfiles.rules = [
      "d /dev/net 0755 root root -"
      "c! /dev/net/tun 0600 root root - 10:200"
    ];

    # Fetch the version-matched agent from the Coder server at boot (mirrors what
    # Coder's generated init script does) and exec it. PassEnvironment forwards the
    # jobspec-injected env from PID 1 to the service.
    services = {
      coder-agent = {
        description = "Coder workspace agent";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        path = [pkgs.curl];
        serviceConfig = {
          User = "coder";
          WorkingDirectory = "/home/coder";
          PassEnvironment = "CODER_AGENT_URL CODER_AGENT_TOKEN";
          ExecStart = pkgs.writeShellScript "coder-agent-start" ''
            set -eu
            bin="$(mktemp -d)/coder"
            curl -fsSL "$CODER_AGENT_URL/bin/coder-linux-amd64" -o "$bin"
            chmod +x "$bin"
            exec "$bin" agent
          '';
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # --- Tailnet membership --------------------------------------------------
      # The workspace joins cow-justice.ts.net as an ephemeral tag:coder node. The
      # auth key arrives as TS_AUTHKEY in the container environment (Nomad jobspec
      # -> PID 1 -> PassEnvironment), the same route CODER_AGENT_TOKEN takes.
      #
      # /var/lib is container rootfs, not the persistent home volume, so tailscaled
      # comes up with no state every boot and logs in fresh each time. That is why
      # the key is ephemeral: a registration that outlived the guest would leave a
      # dead tailnet node behind on every single workspace start.
      #
      # services.tailscale is deliberately NOT used. That module takes tailscaled's
      # unit from the package (systemd.packages) and bakes the TUN mode into a
      # drop-in `Environment=FLAGS=--tun <name>` at BUILD time. This guest has to
      # pick the mode at RUN time (see the probe below), so the unit is written out
      # here rather than fighting a drop-in whose merge order is not ours to set.
      tailscaled = {
        description = "Tailscale node agent";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        # iproute2 for the probe; the other two mirror what nixpkgs' own tailscale
        # module puts on this unit -- `su` (via the wrapper dir) and `getent` are
        # what Tailscale SSH uses to start a session as the right user.
        path = [pkgs.iproute2 pkgs.getent (dirOf config.security.wrapperDir)];
        serviceConfig = {
          Type = "notify";
          StateDirectory = "tailscale";
          RuntimeDirectory = "tailscale";
          RuntimeDirectoryMode = "0755";
          Restart = "on-failure";
          RestartSec = 5;
          ExecStopPost = "${pkgs.tailscale}/bin/tailscaled --cleanup";
          ExecStart = pkgs.writeShellScript "tailscaled-start" ''
            # Pick the TUN mode by PROBING, not by inferring: creating and then
            # deleting a throwaway tun exercises CAP_NET_ADMIN, the /dev node and
            # the driver in one go, which is exactly the set tailscaled needs.
            # Reading CapBnd out of /proc would test only the first of the three.
            #
            # Today the probe fails: the docker driver's allow_caps on pwu-compute1
            # does not list net_admin, so the workspace's bounding set is
            # 0xa82425fb and `ip tuntap add` returns EPERM. Userspace networking
            # needs neither the capability nor the device, so the node still joins
            # the tailnet -- it just routes through netstack instead of a real
            # interface. To get the real one: add net_admin to allow_caps in
            # flatcar/pwu-compute1.bu AND to cap_add in the workspace jobspec, in
            # that order. A task asking for a capability the plugin does not allow
            # is rejected outright, so doing the jobspec first breaks placement.
            if ip tuntap add dev ts-probe mode tun 2>/dev/null; then
              ip tuntap del dev ts-probe mode tun
              tun=tailscale0
            else
              echo "tailscaled: no CAP_NET_ADMIN; using userspace networking." >&2
              echo "tailscaled: inbound and Tailscale SSH work as normal, but" >&2
              echo "tailscaled: OUTBOUND needs the proxy on localhost:1055." >&2
              tun=userspace-networking
            fi

            # The SOCKS5 and HTTP proxies run in BOTH modes on purpose, and share
            # one port -- tailscaled demultiplexes them. In userspace mode they
            # are the only way out. In TUN mode nothing needs them any more, now
            # that --accept-dns hands resolution to 100.100.100.100 (see
            # tailscale-up below); they stay so that a workspace which lands on
            # a node without net_admin still has a way out rather than none.
            exec ${pkgs.tailscale}/bin/tailscaled \
              --state=/var/lib/tailscale/tailscaled.state \
              --socket=/run/tailscale/tailscaled.sock \
              --port=41641 \
              --tun="$tun" \
              --socks5-server=localhost:1055 \
              --outbound-http-proxy-listen=localhost:1055
          '';
        };
      };

      tailscale-up = {
        description = "Join the tailnet";
        wantedBy = ["multi-user.target"];
        after = ["tailscaled.service"];
        wants = ["tailscaled.service"];
        path = [pkgs.tailscale];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PassEnvironment = "TS_AUTHKEY TS_HOSTNAME";
          # Flags and reasons on tailscaleJoin above. `ws-escalate down`
          # restarts this unit to drop back to the baseline key.
          ExecStart = tailscaleJoin;
        };
      };

      # Orca's headless runtime, which the desktop and mobile apps pair with.
      # No bind flag, so it listens everywhere; the tailnet policy (owner's
      # devices -> tag:coder) is the gate, pairing is a one-time code and the
      # session is end-to-end encrypted. Advertises this node's MagicDNS name
      # so the pairing link dials somewhere reachable. Xvfb must be on PATH:
      # Orca starts its own on :99. Runs as coder so the profile under
      # ~/.config persists. KillMode, RestartPreventExitStatus=3 (another Orca
      # owns the profile) and the start limit are upstream's headless unit.
      # Pairing link:
      #   journalctl -u orca-serve -o cat | jq -r 'fromjson? | select(.type == "orca_server_ready") | .pairing.url'
      orca-serve = {
        description = "Orca runtime server";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "tailscale-up.service"];
        wants = ["network-online.target" "tailscale-up.service"];
        path = [orca pkgs.xorg-server pkgs.tailscale pkgs.jq];
        environment.LIBGL_ALWAYS_SOFTWARE = "1";
        unitConfig = {
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        serviceConfig = {
          User = "coder";
          WorkingDirectory = "/home/coder";
          KillMode = "mixed";
          Restart = "on-failure";
          RestartPreventExitStatus = 3;
          RestartSec = 5;
          ExecStart = pkgs.writeShellScript "orca-serve-start" ''
            set -eu
            addr="$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName // "" | rtrimstr(".")')"
            set -- --port 6768 --json
            if [ -n "$addr" ]; then
              set -- "$@" --pairing-address "$addr"
            fi
            exec orca-ide serve "$@"
          '';
        };
      };

      # A second browser terminal, existing only to carry the font Coder's own
      # one cannot (see hackNerdWoff2 above). Reached as a coder_app, which is
      # path-proxied rather than served on a subdomain: *.coder.calculon.tech
      # resolves but has no certificate, because Cloudflare Universal SSL
      # covers one label and that wildcard sits two deep.
      ttyd = {
        description = "Browser terminal that carries its own Nerd Font";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        path = [pkgs.ttyd pkgs.curl pkgs.perl pkgs.coreutils];
        serviceConfig = {
          User = "coder";
          WorkingDirectory = "/home/coder";
          RuntimeDirectory = "ttyd";
          Restart = "on-failure";
          RestartSec = 2;

          # ttyd's client is one self-contained index.html compiled into the
          # binary, with no file on disk to patch and no second asset to serve
          # alongside it -- which is also why the font has to be inlined rather
          # than linked. The only way to get a copy is to ask a running ttyd
          # for it, so start a throwaway one on loopback, take its page, and
          # inject the <style> into <head> before the real one starts with
          # --index. Ports are tried in turn because this is a fixed range on a
          # machine we do not exclusively own.
          ExecStartPre = pkgs.writeShellScript "ttyd-build-index" ''
            set -eu
            raw="$RUNTIME_DIRECTORY/raw.html"
            rm -f "$raw"
            for port in $(seq 7690 7699); do
              ttyd -p "$port" -i lo /bin/true &
              pid=$!
              for _ in $(seq 1 40); do
                curl -sf -o "$raw" "http://127.0.0.1:$port/" && break
                sleep 0.1
              done
              kill "$pid" 2>/dev/null || true
              wait "$pid" 2>/dev/null || true
              [ -s "$raw" ] && break
            done
            [ -s "$raw" ]
            perl -0777 -pe '
              BEGIN { open my $f, "<", $ENV{STYLE} or die $!; local $/; $s = <$f> }
              s/<head>/<head>$s/ or die "ttyd index has no <head>\n"
            ' "$raw" > "$RUNTIME_DIRECTORY/index.html"
          '';

          # No --base-path. Coder's path proxy strips the
          # /@owner/workspace.agent/apps/<slug> prefix before forwarding
          # (coderd/workspaceapps/proxy.go: "Web applications typically request
          # paths relative to the root URL"), so ttyd sees / and its client,
          # which builds the /token and /ws URLs from window.location, still
          # addresses them through the prefix the browser is on. Setting
          # --base-path here would make ttyd 404 every proxied request.
          ExecStart = pkgs.writeShellScript "ttyd-start" ''
            exec ttyd \
              --port 7681 \
              --interface lo \
              --writable \
              --index "$RUNTIME_DIRECTORY/index.html" \
              --client-option 'fontFamily=Hack Nerd Font Mono, monospace' \
              --client-option fontSize=14 \
              ${pkgs.fish}/bin/fish --login
          '';
        };
        environment.STYLE = "${ttydFontStyle}";
      };
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs;
      username = "coder";
      hostname = "coder";
      system = "x86_64-linux";
    };
    users.coder = import ../home/coder.nix;
  };

  system.stateVersion = "24.05";
}
