# Helix editor: one Nix-defined config, materialised into both Helix config
# trees that exist on these machines.
#
# yazelix's managed Helix launches with `--config-dir ~/.config/yazelix/helix`
# and merges that tree's config.toml over its own generated defaults; it never
# reads ~/.config/helix (yazelix's helix_managed_config_contract.md is explicit
# that personal Helix config stays untouched, and its stub writer only ever
# creates a steel_plugins README there). Vanilla `hx` reads only ~/.config/helix.
# Pointing both trees at the same generated files is what makes `hx` the same
# editor inside and outside a yazelix session.
#
# Language tooling is a catalog rather than a flat package list so that hosts
# can drop what they never edit -- see dev.helix.disable in home/chromebook.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrNames
    attrValues
    concatLists
    concatMap
    elem
    filter
    filterAttrs
    foldl'
    mapAttrs
    mapAttrsToList
    mkIf
    mkOption
    optional
    optionalAttrs
    removeAttrs
    types
    unique
    zipAttrsWith
    ;

  cfg = config.dev.helix;

  # conform-nvim ran isort then black over Python buffers. A Helix formatter is
  # a single command reading stdin, so the pipeline needs a script.
  pythonFormatter = pkgs.writeShellScript "helix-format-python" ''
    ${pkgs.isort}/bin/isort - --quiet | ${pkgs.black}/bin/black - --quiet
  '';

  # One entry per language group.
  #
  #   packages  tools that must be on PATH. These go in home.packages, not
  #             programs.helix.extraPackages: that option only wraps the `hx`
  #             binary's PATH, and yazelix's Helix is a different binary.
  #   langs     keyed by Helix language id and merged across entries, so more
  #             than one entry can contribute servers to the same language.
  #   efm       efm-langserver diagnostic sources, replacing the none-ls
  #             linters. Any language with sources gets "efm" appended to its
  #             server list automatically. Anything with lint-stdin = false
  #             reads the file from disk, so it is pinned to lint-on-save.
  catalog = {
    bash = {
      packages = [pkgs.bash-language-server pkgs.shellcheck pkgs.shfmt];
      # bash-language-server shells out to shellcheck itself, so the linter
      # needs no efm entry -- only a place on PATH.
      langs.bash = {
        servers = ["bash-language-server"];
        auto-format = true;
        formatter = {
          command = "shfmt";
          args = ["-i" "2" "-"];
        };
      };
    };

    c = {
      packages = [pkgs.clang-tools pkgs.lldb];
      langs.c.servers = ["clangd"];
      langs.cpp.servers = ["clangd"];
    };

    css = {
      packages = [pkgs.vscode-langservers-extracted];
      langs.css.servers = ["vscode-css-language-server"];
    };

    docker = {
      packages = [pkgs.dockerfile-language-server-nodejs];
      langs.dockerfile.servers = ["docker-langserver"];
    };

    go = {
      packages = [pkgs.gopls pkgs.gotools pkgs.golangci-lint pkgs.delve];
      langs.go = {
        servers = ["gopls"];
        auto-format = true;
        formatter.command = "goimports";
      };
      efm.go = [
        {
          # golangci-lint takes packages rather than a file, so it runs over
          # the whole module from the workspace root.
          lint-command = "golangci-lint run --show-stats=false --output.text.print-issued-lines=false --output.text.colors=false ./...";
          lint-workspace = true;
          lint-stdin = false;
          lint-ignore-exit-code = true;
          lint-source = "golangci-lint";
          lint-formats = ["%f:%l:%c: %m"];
          # Reads the tree from disk, and is far too slow to run per keystroke.
          lint-on-save = true;
          root-markers = ["go.mod"];
          require-marker = true;
        }
      ];
    };

    html = {
      packages = [pkgs.vscode-langservers-extracted];
      langs.html.servers = ["vscode-html-language-server"];
    };

    ltex = {
      packages = [pkgs.ltex-ls];
      langs.markdown.servers = ["ltex-ls"];
      langs.latex.servers = ["ltex-ls"];
    };

    lua = {
      packages = [pkgs.lua-language-server pkgs.stylua];
      langs.lua = {
        servers = ["lua-language-server"];
        auto-format = true;
        formatter = {
          command = "stylua";
          args = ["-"];
        };
      };
    };

    markdown = {
      packages = [pkgs.marksman];
      langs.markdown.servers = ["marksman"];
    };

    nix = {
      packages = [pkgs.nil pkgs.alejandra];
      langs.nix = {
        servers = ["nil"];
        auto-format = true;
        formatter = {
          command = "alejandra";
          args = ["-q" "-"];
        };
      };
    };

    python = {
      packages = [pkgs.pyright pkgs.isort pkgs.black pkgs.mypy pkgs.pylint];
      langs.python = {
        servers = ["pyright"];
        auto-format = true;
        formatter.command = "${pythonFormatter}";
      };
      efm.python = [
        {
          lint-command = "pylint --output-format=text --score=no --msg-template='{path}:{line}:{column}:{C}: {msg} ({symbol})' \${INPUT}";
          lint-stdin = false;
          lint-ignore-exit-code = true;
          lint-source = "pylint";
          lint-formats = ["%f:%l:%c:%t: %m"];
          lint-on-save = true;
          # pylint columns are 0-based; LSP and efm expect 1-based.
          lint-offset-columns = 1;
          lint-category-map = {
            C = "I";
            R = "I";
            W = "W";
            E = "E";
            F = "E";
          };
        }
        {
          lint-command = "mypy --show-column-numbers --no-error-summary --no-pretty \${INPUT}";
          lint-stdin = false;
          lint-ignore-exit-code = true;
          lint-source = "mypy";
          lint-formats = ["%f:%l:%c: %t%*[^:]: %m"];
          lint-on-save = true;
        }
      ];
    };

    rust = {
      packages = [pkgs.rust-analyzer pkgs.rustc pkgs.cargo pkgs.lldb];
      langs.rust.servers = ["rust-analyzer"];
    };

    terraform = {
      packages = [pkgs.terraform-ls pkgs.hclfmt pkgs.tfsec];
      # Helix's built-in hcl language already covers .tf, .hcl and .nomad, so
      # the nomad filetype nixvim had to register comes for free.
      langs.hcl = {
        servers = ["terraform-ls"];
        auto-format = true;
        formatter.command = "hclfmt";
      };
      langs.tfvars = {
        servers = ["terraform-ls"];
        auto-format = true;
        formatter.command = "hclfmt";
      };
      efm.hcl = [
        {
          # tfsec only emits machine-readable output as CSV
          # (file,start,end,rule,severity,description,url,ignored), so awk
          # reshapes it into something an errorformat can read.
          lint-command = "tfsec --no-color --soft-fail --format csv . | awk -F, 'NF>=6 && $2 ~ /^[0-9]+$/ { msg=$6; for (i=7; i<=NF-2; i++) msg=msg\",\"$i; printf \"%s:%s: %s: %s (%s)\\n\", $1, $2, $5, msg, $4 }'";
          lint-workspace = true;
          lint-stdin = false;
          lint-ignore-exit-code = true;
          lint-source = "tfsec";
          lint-formats = ["%f:%l: %t%*[A-Z]: %m"];
          lint-on-save = true;
          lint-category-map = {
            C = "E";
            H = "E";
            M = "W";
            L = "I";
          };
        }
      ];
    };

    typescript = {
      packages = [pkgs.typescript-language-server];
      langs.typescript.servers = ["typescript-language-server"];
    };

    yaml = {
      packages = [pkgs.yaml-language-server pkgs.yamlfix pkgs.yamllint pkgs.ansible-lint];
      langs.yaml = {
        servers = ["yaml-language-server"];
        auto-format = true;
        formatter = {
          command = "yamlfix";
          args = ["-"];
        };
      };
      efm.yaml = [
        {
          lint-command = "yamllint -f parsable -";
          lint-stdin = true;
          lint-ignore-exit-code = true;
          lint-source = "yamllint";
          lint-formats = ["%f:%l:%c: [%t%*[a-z]] %m"];
          lint-after-open = true;
        }
        {
          # Scoped to repos that are actually Ansible, otherwise every stray
          # YAML file in a repo picks up playbook rules.
          lint-command = "ansible-lint --nocolor --parseable \${INPUT}";
          lint-stdin = false;
          lint-ignore-exit-code = true;
          lint-source = "ansible-lint";
          lint-formats = ["%f:%l:%c: %m" "%f:%l: %m"];
          lint-on-save = true;
          root-markers = ["ansible.cfg" ".ansible-lint"];
          require-marker = true;
        }
      ];
    };

    zig = {
      packages = [pkgs.zls];
      langs.zig.servers = ["zls"];
    };
  };

  active = attrValues (removeAttrs catalog cfg.disable);

  # Linters are filtered by lint-source so a host can drop a single tool
  # without giving up the whole language.
  efmLanguages =
    filterAttrs (_: tools: tools != [])
    (mapAttrs (_: tools: filter (t: !(elem t.lint-source cfg.disableLinters)) tools)
      (zipAttrsWith (_: concatLists) (map (e: e.efm or {}) active)));

  efmConfig = (pkgs.formats.yaml {}).generate "efm-langserver.yaml" {
    version = 2;
    root-markers = [".git/"];
    languages = efmLanguages;
  };

  languageList =
    mapAttrsToList (name: v:
      (removeAttrs v ["servers"])
      // {
        inherit name;
        language-servers =
          v.servers
          ++ optional (elem name (attrNames efmLanguages)) "efm";
      })
    (zipAttrsWith (_: defs:
      (foldl' (a: b: a // b) {} defs)
      // {servers = unique (concatMap (d: d.servers or []) defs);})
    (map (e: e.langs or {}) active));
in {
  options.dev.helix = {
    disable = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["rust" "zig"];
      description = ''
        Language catalog entries to leave out on this host. Drops the entry's
        language servers, formatters, debuggers and linters.
      '';
    };

    disableLinters = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["tfsec"];
      description = ''
        efm-langserver diagnostic sources to leave out, named by their
        lint-source. For dropping a single linter while keeping its language.
      '';
    };
  };

  config = {
    home.packages =
      concatMap (e: e.packages) active
      ++ optional (efmLanguages != {}) pkgs.efm-langserver;

    programs.helix = {
      enable = true;
      # Owns EDITOR and VISUAL; the per-host home/*.nix files no longer set them.
      defaultEditor = true;

      settings = {
        # Closest bundled theme to the oxocarbon colorscheme nixvim used --
        # same IBM Carbon palette. Helix ships no oxocarbon.
        theme = "carbonfox";

        editor = {
          line-number = "relative";
          cursorline = true;
          color-modes = true;
          bufferline = "multiple";
          scrolloff = 8;
          idle-timeout = 300;
          true-color = true;
          # conform-nvim's `_ = ["trim_whitespace"]` catch-all.
          trim-trailing-whitespace = true;
          trim-final-newlines = true;

          lsp = {
            display-inlay-hints = true;
            display-messages = true;
            display-progress-messages = true;
          };

          # Replaces the nixvim diagnostic float-on-CursorHold autocmd.
          inline-diagnostics = {
            cursor-line = "hint";
            other-lines = "error";
          };
          end-of-line-diagnostics = "hint";
        };

        # Helix's own space menu already covers the telescope bindings; `-`
        # is the one carry-over worth keeping, from oil.nvim.
        keys.normal."-" = "file_picker_in_current_directory";
      };

      languages = {
        language-server =
          {
            lua-language-server.config.Lua.telemetry.enable = false;
            ltex-ls.config.ltex = {
              language = "en-US";
              enabled = ["latex" "tex" "markdown"];
              completionEnabled = true;
            };
          }
          // optionalAttrs (efmLanguages != {}) {
            efm = {
              command = "efm-langserver";
              args = ["-c" "${efmConfig}"];
            };
          };

        language = languageList;
      };
    };

    # The second config tree. Guarded because a host with yazelix off (see
    # home/chromebook.nix) has no ~/.config/yazelix to populate.
    xdg.configFile = mkIf config.programs.yazelix.enable {
      "yazelix/helix/config.toml".source =
        config.xdg.configFile."helix/config.toml".source;
      "yazelix/helix/languages.toml".source =
        config.xdg.configFile."helix/languages.toml".source;
    };
  };
}
