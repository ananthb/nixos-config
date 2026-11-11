# macOS 27 only starts the screen saver when the display sleeps, so poll HID
# idle here and start it at a fixed threshold without touching the pmset profile.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.macosIdleLock;
  idleNanoseconds = toString (cfg.idleSeconds * 1000000000);
  lock = pkgs.writeShellScript "macos-idle-lock" ''
    idle="$(/usr/sbin/ioreg -c IOHIDSystem \
      | /usr/bin/awk '/HIDIdleTime/ { print $NF; exit }')"
    [ -n "$idle" ] || exit 0
    [ "$idle" -ge ${idleNanoseconds} ] || exit 0

    # Skip while locked so the saver is not relaunched on every poll.
    /usr/sbin/ioreg -n Root -d1 | /usr/bin/grep -q CGSSessionScreenIsLocked && exit 0

    # Skip whenever something is keeping the display awake -- full-screen
    # video, a call, a presentation. That assertion is exactly what stops
    # macOS from sleeping the display mid-video, and the screen saver fires
    # with the display sleep, so honouring it keeps playback uninterrupted.
    # Without this the HID timer below locks the screen over any long video.
    /usr/bin/pmset -g assertions \
      | /usr/bin/awk '/^ *PreventUserIdleDisplaySleep/ { found = ($2 != 0) } END { exit found ? 0 : 1 }' \
      && exit 0

    # Start the saver, not a display sleep, so the pmset profile stays untouched.
    /usr/bin/open -b com.apple.ScreenSaver.Engine
  '';
in {
  options.services.macosIdleLock = {
    enable = lib.mkEnableOption "locking the screen after idle";

    idleSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds of HID idle before the screen saver starts; the password delay adds to this.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.agents.macos-idle-lock = {
      enable = true;
      config = {
        ProgramArguments = ["${lock}"];
        RunAtLoad = true;
        StartInterval = 5;
      };
    };
  };
}
