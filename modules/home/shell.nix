_: {
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
}
