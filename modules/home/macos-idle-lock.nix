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

    # Start the saver, not a display sleep, so the pmset profile stays untouched.
    /usr/bin/open -b com.apple.ScreenSaver.Engine
  '';
in {
  options.services.macosIdleLock = {
    enable = lib.mkEnableOption "locking the screen after idle";

    idleSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
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
