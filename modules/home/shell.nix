{
  lib,
  pkgs,
  ...
}: {
  programs.bash = {
    enable = true;
    historyControl = ["ignoredups" "erasedups"];
    historySize = 100000;
    historyFileSize = 100000;
    shellOptions = [
      "histappend"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
    ];
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      gs = "git status -sb";
      gd = "git diff";
      gl = "git log --oneline";
    };
  };

  # home-manager's NixOS module runs the activation from a login shell: the
  # unit's ExecStart is `hm-setup-env`, whose shebang is `bash -el`, and it
  # sources the dotfiles before it execs `activate`. But home-manager's own
  # ~/.bashrc opens with the standard interactive guard
  #
  #   [[ $- == *i* ]] || return
  #
  # and a bare `return` carries the status of the last command -- here the
  # failed test, so 1. `-e` then kills the shell at that `return`, before
  # `activate` ever runs. The unit fails with an empty log (nothing has
  # written to stdout yet) and switch-to-configuration reports exit 4 on a
  # system that built and switched fine otherwise. It only surfaces on the
  # *second* switch onwards: the first activation on a fresh machine runs
  # before ~/.bashrc exists.
  #
  # Re-emit .bash_profile with the same two includes made non-fatal. `|| true`
  # puts the `.` on the left of a `||`, which errexit exempts, so a dotfile
  # that returns early can no longer take the login shell down with it. In an
  # ordinary interactive login shell `-e` is off and this changes nothing.
  #
  # A machine already in this state cannot pick the fix up from a switch: the
  # corrected .bash_profile is linked by the very activation that keeps dying.
  # Break the loop once by hand with a login shell that has no errexit --
  #   systemctl cat home-manager-$USER.service | grep ExecStart
  #   bash -l -c "exec <the generation path it prints>/activate --driver-version 1"
  # -- after which `nixos-rebuild switch` maintains it on its own.
  home.file.".bash_profile".source = lib.mkForce (pkgs.writeText "bash_profile" ''
    # include .profile if it exists
    if [[ -f ~/.profile ]]; then . ~/.profile || true; fi

    # include .bashrc if it exists
    if [[ -f ~/.bashrc ]]; then . ~/.bashrc || true; fi
  '');
}
