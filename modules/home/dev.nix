# THE development environment. Every profile imports this and gets the same
# CLI: helix, fish, zellij + yazi, git, direnv, gpg, and the package baseline
# below. There is deliberately no second "dev" file and no "common" --
# those existed side by side and drifted, so `git`, `mosh`, `htop` and friends
# were copy-pasted across four profiles and `htop` reached only one of them.
#
# What does NOT belong here: secrets (sops, YubiKeys) and anything host- or
# platform-specific. Those live in the consuming profile -- home/discovery.nix
# is the only one with any, because it is the only host with key material.
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./helix.nix
  ];

  # Building `man home-configuration.nix` forces nixpkgs' options.json doc
  # derivation, which embeds the nixpkgs source path without string context and
  # so warns on every evaluation. The manual is online; skip the build.
  manual.manpages.enable = false;

  # The baseline. Anything genuinely used in every environment goes here, not
  # in a profile. Tools that a programs.* block already installs (git, fd, bat,
  # eza, zoxide, atuin, gnupg) are deliberately absent -- listing them again is
  # a second place to forget, and shows up as a duplicate in the profile.
  # `delta` IS listed: git uses it as the pager via settings, which does not
  # pull the package in on its own.
  home.packages = with pkgs; [
    claude-code
    coder
    delta
    devenv
    fzf
    gh
    git-absorb
    glab
    nerd-fonts.hack
    htop
    jq
    lazygit
    mosh
    nix-output-monitor
    ripgrep
  ];

  programs = {
    home-manager.enable = true;

    atuin = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        style = "compact";
        inline_height = 20;
        show_preview = true;
        enter_accept = true;
      };
    };

    bat = {
      enable = true;
      config.theme = "base16-256";
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      git = true;
      icons = "auto";
    };

    fd = {
      enable = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting ""

        # Auto-fetch git repos in the background on directory change
        function __auto_git_fetch --on-variable PWD
          if test -d .git
            command git fetch --all --quiet &disown 2>/dev/null
          end
        end
      '';
      shellAbbrs = {
        g = "git";
        ga = "git add";
        gc = "git commit";
        gca = "git commit --amend";
        gco = "git checkout";
        gd = "git diff";
        gds = "git diff --staged";
        gl = "git log --oneline";
        gp = "git push";
        gpf = "git push --force-with-lease";
        gr = "git rebase";
        gs = "git status -sb";
        gsw = "git switch";

        dc = "docker compose";
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcl = "docker compose logs -f";

        k = "kubectl";
        tf = "terraform";

        nr = "nix run";
        ns = "nix shell";
        nb = "nix build";
        nf = "nix flake";
        nd = "nix develop";

        lg = "lazygit";
        v = "hx";
        cat = "bat";
      };
    };

    # Glyphs below are Nerd Font codepoints verified present in
    # nerd-fonts.hack (fc-query on HackNerdFontMono-Regular): branch U+E0A0,
    # nixos U+F313, kubernetes U+F10FE, server U+E795, clock U+F017, lock
    # U+F023, prompt U+276F. Two conventional choices are NOT used because
    # that font lacks them and they render as blank boxes: starship's own
    # default ssh_symbol 🖥 U+1F5A5, and the kubernetes wheel ☸ U+2638.
    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        format = "$hostname$directory$git_branch$git_status$nix_shell$kubernetes$cmd_duration$line_break$character";
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
          read_only = " ";
        };
        git_branch = {
          symbol = " ";
          format = "[$symbol$branch]($style) ";
        };
        git_status.format = "([\\[$all_status$ahead_behind\\]]($style) )";
        nix_shell = {
          format = "[$symbol$state]($style) ";
          symbol = " ";
        };
        kubernetes = {
          disabled = false;
          symbol = "󱃾 ";
          format = "[$symbol$context(/$namespace)]($style) ";
        };
        hostname = {
          ssh_only = true;
          format = "[$ssh_symbol$hostname]($style) ";
          ssh_symbol = " ";
        };
        cmd_duration = {
          min_time = 2000;
          format = "[ $duration]($style) ";
        };
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };
    };

    # Plain zellij, declared here rather than arriving as a side effect.
    # yazelix used to pull the multiplexer in transitively -- and on the Coder
    # workspace that produced no `zellij` on PATH at all, out of 250 binaries.
    # It also brought its own Helix build (a Steel-enabled fork), a second
    # ~/.config/yazelix/helix config tree, its own cachix, and an activation
    # that `nix flake check` could not evaluate. The one integration worth
    # keeping -- yazi opening files into a pane -- is the opener below, which
    # only ever needed $ZELLIJ.
    zellij = {
      enable = true;

      settings = {
        default_shell = "fish";
        # The frames cost two columns and a row per pane and say nothing the
        # status bar does not; pane names are in the tab bar.
        pane_frames = false;
        copy_on_select = true;
        mouse_mode = true;
        scroll_buffer_size = 50000;
        # Resurrect panes after a restart. This matters more here than on a
        # laptop: the workspace runs on a node that resets every few hours.
        session_serialization = true;
      };

      # The yazelix arrangement, rebuilt as a plain layout: file tree on the
      # left, work on the right. Deliberately NOT the default_layout -- `zellij`
      # gives an ordinary session and `zellij --layout dev` gives this one. Set
      # `default_layout = "dev"` above if you would rather have it always.
      #
      # yazi opens files into the right-hand pane through the `opener` further
      # down this file, which only ever needed $ZELLIJ set.
      layouts.dev = ''
        layout {
            pane size=1 borderless=true {
                plugin location="zellij:tab-bar"
            }
            pane split_direction="vertical" {
                pane size="25%" name="files" command="yazi"
                pane name="work"
            }
            pane size=2 borderless=true {
                plugin location="zellij:status-bar"
            }
        }
      '';
    };

    yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      settings = {
        mgr = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
          sort_sensitive = false;
        };
        preview = {
          max_width = 1000;
          max_height = 1000;
        };
        opener = {
          edit = [
            {
              run = ''if [ -n "$ZELLIJ" ]; then zellij edit "$@"; else hx "$@"; fi'';
              block = true;
              for = "unix";
            }
          ];
        };
        open.rules = [
          {
            mime = "text/*";
            use = "edit";
          }
          {
            mime = "application/json";
            use = "edit";
          }
          {
            url = "*";
            use = "edit";
          }
        ];
      };
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    gpg = {
      enable = true;

      # Public key, so it is safe in every environment. Importing it
      # declaratively means `sops updatekeys` can find it after a fresh setup
      # without a manual `gpg --recv-keys`.
      publicKeys = [
        {
          source = ../../home/keys/admin_ananth.asc;
          trust = "ultimate";
        }
      ];
      settings = {
        use-agent = true;
      };

      scdaemonSettings = {
        disable-ccid = true;
        reader-port = "Yubico Yubi";
      };
    };

    git = {
      enable = true;
      signing.format = lib.mkDefault null;

      # One user, so identity is part of the dev env rather than something each
      # profile restates. Signing stays unset here: only hosts with a YubiKey
      # can sign, and they opt in.
      settings.user = {
        name = "Ananth Bhaskararaman";
        email = "antsub@gmail.com";
        useConfigOnly = "true";
      };

      settings = {
        core.editor = "hx";
        core.pager = "delta";
        init.defaultBranch = "main";

        interactive.diffFilter = "delta --color-only";

        delta = {
          navigate = true;
          side-by-side = true;
          line-numbers = true;
          syntax-theme = "base16-256";
          dark = true;
        };

        alias = {
          a = "add";
          b = "branch";
          c = "commit";
          p = "push";
          r = "reset";
          s = "status -sb";
          sw = "switch";
          co = "checkout";
          cp = "cherry-pick";
          absorb = "absorb";
        };

        color = {
          ui = "true";
          diff = "auto";
          status = "auto";
          branch = "auto";
        };

        advice = {
          pushNonFastForward = "false";
          statusHints = "false";
          commitBeforeMerge = "false";
          resolveConflict = "false";
          implicitIdentity = "false";
          detachedHead = "false";
        };

        http.cookieFile = "~/.gitcookies";
        push.autoSetupRemote = true;
        rerere.enabled = "true";
        column.ui = "auto";
        branch.sort = "-committerdate";
        merge.conflictStyle = "zdiff3";
        diff.algorithm = "histogram";
        diff.colorMoved = "default";
        transfer.fsckObjects = "true";
        fetch.fsckObjects = "true";
        receive.fsckObjects = "true";
      };
    };

    nix-index-database.comma.enable = true;
  };
}
