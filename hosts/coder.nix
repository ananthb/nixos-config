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

  # Prints the pairing link a client needs to reach orca-serve here. The
  # runtime emits it once, as one JSON line at startup, and keeps no copy:
  # `orca status` reports readiness but carries no pairing field, so the
  # journal is the only record and this is the supported way to read it.
  #
  # It exists because the pipeline anyone writes by hand is a trap twice
  # over, and both halves fail in a way that reads as "no pairing link" and
  # not as "your command is wrong". The unit interleaves plain-text Electron
  # and dbus lines with its JSON, so jq needs -R or it parses the first of
  # those as an input document and exits before fromjson? is ever reached;
  # and coder could not read the journal at all until the systemd-journal
  # group below.
  #
  # Last line wins: a restart emits a fresh one and the old link is stale.
  orca-pairing = pkgs.writeShellScriptBin "orca-pairing" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then arg=""; else arg="$1"; fi
    case "$arg" in
      "") field=.pairing.url ;;
      --web) field=.pairing.webClientUrl ;;
      --json) field=. ;;
      -h | --help)
        echo "usage: orca-pairing [--web | --json]"
        echo "  (default)  orca://pair link for a desktop or mobile client"
        echo "  --web      browser URL for the web client, code in the fragment"
        echo "  --json     the whole orca_server_ready line"
        exit 0
        ;;
      *)
        echo "orca-pairing: unknown argument: $arg" >&2
        exit 2
        ;;
    esac

    ready="$(${config.systemd.package}/bin/journalctl -u orca-serve -o cat --no-pager |
      ${pkgs.jq}/bin/jq -Rc 'fromjson? | select(.type == "orca_server_ready")' |
      ${pkgs.coreutils}/bin/tail -n 1)"

    if [ -z "$ready" ]; then
      echo "orca-pairing: no pairing line in the journal; orca-serve is $(${config.systemd.package}/bin/systemctl is-active orca-serve)" >&2
      exit 1
    fi

    if [ "$field" = "." ]; then
      printf '%s\n' "$ready" | ${pkgs.jq}/bin/jq .
    else
      printf '%s\n' "$ready" | ${pkgs.jq}/bin/jq -r "$field"
    fi
  '';

  # Joins the tailnet with whichever key the jobspec handed PID 1. Which key
  # that is decides the node's tags and so its reach: the NixOS template picks
  # the tag:coder-trusted one for the owners in tf/shared/coder-owners.json
  # (calculon-tech/platform) and the baseline one for everyone else. The guest
  # does not know or care which it got.
  #
  # --hostname: networking.hostName is "coder" for every workspace; the
  # jobspec passes the workspace's own name, so the MagicDNS name a client
  # dials is the name in the Coder UI and nothing has to be looked up.
  # --accept-dns: tailscaled takes over /etc/resolv.conf and forwards
  # non-tailnet names to the resolver the runtime wrote. Verified on a live
  # workspace; needs the real TUN, userspace mode would black-hole lookups.
  #
  # --force-reauth, on every boot, because tailscaled's state is persistent
  # now (see tailscaled below) and a node that is already logged in ignores
  # the key entirely. The key is what carries the tags, so without this a
  # workspace would keep the tier it first registered with for as long as its
  # home volume lives: adding someone to tf/shared/coder-owners.json would not
  # grant tag:coder-trusted, and -- the half that matters -- REMOVING them
  # would not take it away. Re-auth is not re-registration; it updates the
  # device in place, rotating its node key and keeping its Tailscale IP, so
  # the stable identity this whole change is for survives it.
  tailscaleJoin = pkgs.writeShellScript "tailscale-join" ''
    set -eu
    # No key is not an error: the image must still boot into a usable
    # workspace on a template version that predates TS_AUTHKEY, and on a
    # bare `docker run` of it done by hand for debugging. With state now
    # persistent, a node that logged in on an earlier boot also just stays
    # up rather than dropping off the tailnet.
    if [ -z "''${TS_AUTHKEY:-}" ]; then
      echo "tailscale-join: TS_AUTHKEY is empty; staying logged out." >&2
      exit 0
    fi
    exec ${pkgs.tailscale}/bin/tailscale up \
      --auth-key="$TS_AUTHKEY" \
      --force-reauth \
      --hostname="''${TS_HOSTNAME:-coder}" \
      --accept-dns=true \
      --accept-routes=true \
      --ssh
  '';
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
    # systemd-journal: wheel plus passwordless sudo already reached the
    # journal, but only through sudo, and nothing in the workspace said so --
    # every documented `journalctl -u <unit>` here failed on "No journal files
    # were opened due to insufficient permissions", which reads like an empty
    # journal rather than a missing group. Reading one's own unit logs is the
    # first thing anyone does in this guest, agent or person.
    extraGroups = ["wheel" "systemd-journal"];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  environment.systemPackages = [pkgs.coder pkgs.curl pkgs.git pkgs.tailscale orca orca-pairing];

  # Reduce image size.
  documentation.enable = false;

  systemd = {
    # /dev in the kata guest is a plain tmpfs the runtime populates from the OCI
    # spec, not devtmpfs, so the tun node tailscaled wants is simply absent --
    # even though the guest kernel does carry the driver. Opening a hand-made
    # node returns EBADFD ("file descriptor in bad state"), not ENODEV, which is
    # how you tell those two apart. mknod needs CAP_MKNOD, which is already in
    # the container's bounding set.
    #
    # /home/coder/.tailscale is the other half: tailscaled's state, on the one
    # filesystem in this guest that outlives the container (see tailscaled
    # below). Root-owned 0700 inside the user's home because that home volume
    # is the ONLY persistent mount -- findmnt shows /, /nix/store, /alloc,
    # /local and /secrets all coming from the image or the alloc. Created here
    # rather than by StateDirectory= so it exists before tailscaled starts and
    # with permissions tailscaled will accept.
    tmpfiles.rules = [
      "d /dev/net 0755 root root -"
      "c! /dev/net/tun 0600 root root - 10:200"
      "d /home/coder/.tailscale 0700 root root -"
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
          # FORGEJO_* so every shell the agent spawns can push to the forge.
          # The Nomad template stanza that renders them is in the workspace
          # template (calculon-tech/platform, tf/coder/templates/nixos); the
          # git credential helper that consumes them is in home/coder.nix.
          # They are absent on a `docker run` of this image by hand, and the
          # helper is written to stay quiet when they are.
          PassEnvironment = "CODER_AGENT_URL CODER_AGENT_TOKEN FORGEJO_TOKEN FORGEJO_USER";
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
      # The workspace joins cow-justice.ts.net as one lasting node, tag:coder
      # and for some owners tag:coder-trusted as well. The auth key arrives as
      # TS_AUTHKEY in the container environment (Nomad jobspec -> PID 1 ->
      # PassEnvironment), the same route CODER_AGENT_TOKEN takes.
      #
      # The state file is on the home volume, not in /var/lib, so the workspace
      # comes back as the SAME tailnet device across restarts -- same node, same
      # 100.x address, same MagicDNS name. It used to live in the container
      # rootfs and be thrown away on every boot, which is why the key was
      # ephemeral: a registration that outlived the guest would otherwise have
      # left a dead node behind on each start.
      #
      # Throwing it away cost the thing the name is for. MagicDNS names are
      # unique, so a second device asking for a name another device already
      # holds is given that name with -1 appended. Control reaps an ephemeral
      # node minutes after it goes offline, and a workspace restart is seconds,
      # so the new guest kept registering against its own not-yet-reaped
      # corpse and landing on <workspace>-1 -- which is exactly the address a
      # paired Orca client had stored and now could not reach. One durable node
      # cannot collide with itself.
      #
      # The trade is that deleting a workspace now leaves its node in the
      # tailnet until someone removes it in the admin console. Deletions are
      # rare and a stale tagged node grants nothing on its own; a name silently
      # drifting under a client that had it right was the daily cost.
      # tailscale.tf in calculon-tech/platform mints the matching key.
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
          # No StateDirectory=: that is /var/lib/tailscale, which is container
          # rootfs and resets. The state path below is on the home volume, and
          # tmpfiles above makes the directory.
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
              --state=/home/coder/.tailscale/tailscaled.state \
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
          # Flags and reasons on tailscaleJoin above.
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
      # Pairing link: run `orca-pairing`, defined in the let block above,
      # which is also where the shape of this unit's ready line is written up.
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
          # Same forge credential the Coder terminal gets; this is the other
          # shell people actually type in. See coder-agent above.
          PassEnvironment = "FORGEJO_TOKEN FORGEJO_USER";
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
