# Reusable development environment: nixvim, fish + yazelix (zellij + yazi),
# git (without identity), direnv, gpg. Personal identity, secrets, and
# packages should be set in the consuming config.
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.yazelix.homeManagerModules.default
  ];

  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.helix
  ];

  programs = {
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
        v = "nvim";
        cat = "bat";
      };
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        format = "$hostname$directory$git_branch$git_status$nix_shell$kubernetes$cmd_duration$line_break$character";
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
        };
        git_branch.format = "[$branch]($style) ";
        git_status.format = "([\\[$all_status$ahead_behind\\]]($style) )";
        nix_shell = {
          format = "[$symbol$state]($style) ";
          symbol = "nix ";
        };
        kubernetes = {
          disabled = false;
          format = "[$context(/$namespace)]($style) ";
        };
        hostname = {
          ssh_only = true;
          format = "[$ssh_symbol$hostname]($style) ";
          ssh_symbol = "ssh:";
        };
        cmd_duration = {
          min_time = 2000;
          format = "[$duration]($style) ";
        };
        character = {
          success_symbol = "[>](bold green)";
          error_symbol = "[>](bold red)";
        };
      };
    };

    yazelix = {
      enable = true;
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
              run = ''if [ -n "$ZELLIJ" ]; then zellij edit "$@"; else nvim "$@"; fi'';
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
      publicKeys = [];
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

      settings = {
        core.editor = "nvim";
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

    nixvim = {
      enable = true;

      nixpkgs.useGlobalPackages = true;

      opts = {
        number = true;
        relativenumber = true;
        updatetime = 300;
        signcolumn = "yes";
        undofile = true;
        scrolloff = 8;
        splitright = true;
        splitbelow = true;
      };

      globals.mapleader = " ";

      extraConfigLua = ''
        vim.diagnostic.config({
          virtual_text = {
            spacing = 2,
            prefix = "●",
          },
          severity_sort = true,
          float = {
            border = "rounded",
            source = "if_many",
          },
        })

        vim.filetype.add({
          extension = {
            nomad = "nomad",
          },
        })
      '';

      colorschemes.oxocarbon.enable = true;

      plugins = {
        barbecue.enable = true;
        bufferline.enable = true;

        cmp = {
          enable = true;
          autoEnableSources = true;
          settings.sources = [
            {name = "nvim_lsp";}
            {name = "path";}
            {name = "buffer";}
          ];
        };
        cmp-nvim-lsp.enable = true;

        copilot-lua = {
          enable = true;
          settings = {
            suggestion.enabled = false;
            panel.enabled = false;
          };
        };
        copilot-cmp.enable = true;

        oil = {
          enable = true;
          settings = {
            view_options.show_hidden = true;
            keymaps = {
              "q" = "actions.close";
              "<C-s>" = "actions.select_vsplit";
            };
          };
        };

        fugitive.enable = true;
        gitblame.enable = true;
        gitsigns.enable = true;
        glow.enable = true;
        illuminate.enable = true;

        flash = {
          enable = true;
          settings.modes.search.enabled = false;
        };

        nvim-surround.enable = true;
        harpoon.enable = true;

        undotree = {
          enable = true;
          settings.FocusOnToggle = true;
        };

        numbertoggle.enable = true;

        lsp = {
          enable = true;

          inlayHints = true;

          onAttach = ''
                   if not client.supports_method("textDocument/codeLens") then
              return
            end
            local group = vim.api.nvim_create_augroup("LspCodeLens." .. bufnr, {})
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
              group = group,
              buffer = bufnr,
              callback = vim.lsp.codelens.refresh,
            })

            local diag_group = vim.api.nvim_create_augroup("LspDiagnosticsFloat." .. bufnr, {})
            vim.api.nvim_create_autocmd("CursorHold", {
              group = diag_group,
              buffer = bufnr,
              callback = function()
                local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
                if next(vim.diagnostic.get(bufnr, { lnum = lnum })) == nil then
                  return
                end
                vim.diagnostic.open_float(nil, { focus = false, scope = "line" })
              end,
            })
          '';

          servers = {
            bashls.enable = true;
            clangd.enable = true;
            cssls.enable = true;
            dockerls.enable = true;

            gopls = {
              enable = true;
              autostart = true;
            };

            html.enable = true;

            ltex = {
              enable = true;
              settings = {
                enabled = [
                  "latex"
                  "text"
                  "tex"
                  "tex"
                ];
                completionEnabled = true;
                language = "en-US";
              };
            };

            lua_ls = {
              enable = true;
              settings.telemetry.enable = false;
            };

            marksman.enable = true;
            nil_ls.enable = true;
            pyright.enable = true;

            rust_analyzer = {
              enable = true;
              installRustc = true;
              installCargo = true;
            };

            terraformls.enable = true;
            ts_ls.enable = true;
            yamlls.enable = true;
            zls.enable = true;
          };
        };

        conform-nvim = {
          enable = true;
          settings = {
            format_on_save = {
              timeout_ms = 2000;
              lsp_format = "fallback";
            };
            formatters_by_ft = {
              go = ["gofmt" "goimports"];
              python = ["isort" "black"];
              terraform = ["terraform_fmt"];
              hcl = ["hclfmt"];
              nomad = ["hclfmt"];
              yaml = ["yamlfix"];
              nix = ["alejandra"];
              lua = ["stylua"];
              "_" = ["trim_whitespace"];
            };
          };
        };

        lsp-signature.enable = true;
        lualine.enable = true;
        navic.enable = true;
        nix.enable = true;
        noice.enable = false;
        none-ls = {
          enable = true;
          sources = {
            diagnostics = {
              ansiblelint.enable = true;
              golangci_lint.enable = true;
              mypy.enable = true;
              pylint.enable = true;
              terraform_validate.enable = true;
              tfsec.enable = true;
              yamllint.enable = true;
            };
          };
        };
        nvim-autopairs.enable = true;
        sleuth.enable = true;

        treesitter = {
          enable = true;
          highlight.enable = true;
        };
        treesitter-textobjects.enable = true;

        yazi.enable = true;
        zellij-nav.enable = true;

        telescope = {
          enable = true;
          extensions = {
            fzf-native.enable = true;
            file-browser.enable = true;
          };
          keymaps = {
            "<leader>f'" = {
              action = "marks";
              options.desc = "View marks";
            };
            "<leader>f/" = {
              action = "current_buffer_fuzzy_find";
              options.desc = "Fuzzy find in current buffer";
            };
            "<leader>f<CR>" = {
              action = "resume";
              options.desc = "Resume action";
            };
            "<leader>fa" = {
              action = "autocommands";
              options.desc = "View autocommands";
            };
            "<leader>fC" = {
              action = "commands";
              options.desc = "View commands";
            };
            "<leader>fb" = {
              action = "file_browser";
              options.desc = "Open File Browser";
            };
            "<leader>fB" = {
              action = "buffers";
              options.desc = "View buffers";
            };
            "<leader>fd" = {
              action = "diagnostics";
              options.desc = "View diagnostics";
            };
            "<leader>fg" = {
              action = "grep_string";
              options.desc = "Grep string";
            };
            "<leader>ff" = {
              action = "find_files";
              options.desc = "Find files";
            };
            "<leader>fh" = {
              action = "help_tags";
              options.desc = "View help tags";
            };
            "<leader>fm" = {
              action = "man_pages";
              options.desc = "View man pages";
            };
            "<leader>fo" = {
              action = "oldfiles";
              options.desc = "View old files";
            };
            "<leader>fr" = {
              action = "registers";
              options.desc = "View registers";
            };
            "<leader>fs" = {
              action = "lsp_document_symbols";
              options.desc = "Search symbols";
            };
            "<leader>fq" = {
              action = "quickfix";
              options.desc = "Search quickfix";
            };
            "<leader>gd" = {
              action = "lsp_definitions";
              options.desc = "Go to Definitions";
            };
            "<leader>gr" = {
              action = "lsp_references";
              options.desc = "List References";
            };
            "<leader>gI" = {
              action = "lsp_implementations";
              options.desc = "Go to Implementations";
            };
            "<leader>gt" = {
              action = "lsp_type_definitions";
              options.desc = "Go to Type Definitions";
            };
          };
        };

        todo-comments = {
          enable = true;
          settings.colors = {
            error = [
              "DiagnosticError"
              "ErrorMsg"
              "#DC2626"
            ];
            warning = [
              "DiagnosticWarn"
              "WarningMsg"
              "#FBBF24"
            ];
            info = [
              "DiagnosticInfo"
              "#2563EB"
            ];
            hint = [
              "DiagnosticHint"
              "#10B981"
            ];
            default = [
              "Identifier"
              "#7C3AED"
            ];
            test = [
              "Identifier"
              "#FF00FF"
            ];
          };
        };

        dap = {
          enable = true;
          extensionConfigLua = ''
            local dap_ok, dap = pcall(require, "dap")
            if dap_ok then
              local dapui_ok, dapui = pcall(require, "dapui")
              if dapui_ok then
                dap.listeners.after.event_initialized["dapui_config"] = function()
                  dapui.open()
                end
                dap.listeners.before.event_terminated["dapui_config"] = function()
                  dapui.close()
                end
                dap.listeners.before.event_exited["dapui_config"] = function()
                  dapui.close()
                end
              end
            end
          '';
        };
        dap-go.enable = true;
        dap-lldb.enable = true;
        dap-python.enable = true;
        dap-ui.enable = true;
        dap-virtual-text.enable = true;

        trouble.enable = true;
        web-devicons.enable = true;
        which-key.enable = true;
        zig.enable = true;
      };

      keymaps = [
        {
          key = "-";
          action = "<cmd>Oil<cr>";
          options.desc = "Open parent directory";
        }
        {
          key = "<leader>u";
          action = "<cmd>UndotreeToggle<cr>";
          options.desc = "Toggle undotree";
        }
        {
          key = "<leader>fl";
          action = "<cmd>Telescope live_grep<cr>";
          options.desc = "Live grep";
        }
        {
          key = "<leader>ha";
          action.__raw = "function() require'harpoon':list():add() end";
          options.desc = "Harpoon add file";
        }
        {
          key = "<leader>hh";
          action.__raw = "function() local harpoon = require'harpoon'; harpoon.ui:toggle_quick_menu(harpoon:list()) end";
          options.desc = "Harpoon menu";
        }
        {
          key = "<leader>h1";
          action.__raw = "function() require'harpoon':list():select(1) end";
          options.desc = "Harpoon file 1";
        }
        {
          key = "<leader>h2";
          action.__raw = "function() require'harpoon':list():select(2) end";
          options.desc = "Harpoon file 2";
        }
        {
          key = "<leader>h3";
          action.__raw = "function() require'harpoon':list():select(3) end";
          options.desc = "Harpoon file 3";
        }
        {
          key = "<leader>h4";
          action.__raw = "function() require'harpoon':list():select(4) end";
          options.desc = "Harpoon file 4";
        }

        # treesitter-textobjects: select
        {
          mode = ["o" "x"];
          key = "af";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@function.outer', 'textobjects') end";
          options.desc = "around function";
        }
        {
          mode = ["o" "x"];
          key = "if";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@function.inner', 'textobjects') end";
          options.desc = "inner function";
        }
        {
          mode = ["o" "x"];
          key = "ac";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@class.outer', 'textobjects') end";
          options.desc = "around class";
        }
        {
          mode = ["o" "x"];
          key = "ic";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@class.inner', 'textobjects') end";
          options.desc = "inner class";
        }
        {
          mode = ["o" "x"];
          key = "aa";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.outer', 'textobjects') end";
          options.desc = "around parameter";
        }
        {
          mode = ["o" "x"];
          key = "ia";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.inner', 'textobjects') end";
          options.desc = "inner parameter";
        }
        {
          mode = ["o" "x"];
          key = "ai";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@conditional.outer', 'textobjects') end";
          options.desc = "around conditional";
        }
        {
          mode = ["o" "x"];
          key = "ii";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@conditional.inner', 'textobjects') end";
          options.desc = "inner conditional";
        }
        {
          mode = ["o" "x"];
          key = "al";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@loop.outer', 'textobjects') end";
          options.desc = "around loop";
        }
        {
          mode = ["o" "x"];
          key = "il";
          action.__raw = "function() require('nvim-treesitter-textobjects.select').select_textobject('@loop.inner', 'textobjects') end";
          options.desc = "inner loop";
        }

        # treesitter-textobjects: move
        {
          key = "]f";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer', 'textobjects') end";
          options.desc = "next function start";
        }
        {
          key = "]c";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@class.outer', 'textobjects') end";
          options.desc = "next class start";
        }
        {
          key = "]a";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_start('@parameter.inner', 'textobjects') end";
          options.desc = "next parameter";
        }
        {
          key = "]F";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_end('@function.outer', 'textobjects') end";
          options.desc = "next function end";
        }
        {
          key = "]C";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_next_end('@class.outer', 'textobjects') end";
          options.desc = "next class end";
        }
        {
          key = "[f";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer', 'textobjects') end";
          options.desc = "previous function start";
        }
        {
          key = "[c";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@class.outer', 'textobjects') end";
          options.desc = "previous class start";
        }
        {
          key = "[a";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_start('@parameter.inner', 'textobjects') end";
          options.desc = "previous parameter";
        }
        {
          key = "[F";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_end('@function.outer', 'textobjects') end";
          options.desc = "previous function end";
        }
        {
          key = "[C";
          action.__raw = "function() require('nvim-treesitter-textobjects.move').goto_previous_end('@class.outer', 'textobjects') end";
          options.desc = "previous class end";
        }

        # treesitter-textobjects: swap
        {
          key = "<leader>sa";
          action.__raw = "function() require('nvim-treesitter-textobjects.swap').swap_next('@parameter.inner') end";
          options.desc = "swap next parameter";
        }
        {
          key = "<leader>sA";
          action.__raw = "function() require('nvim-treesitter-textobjects.swap').swap_previous('@parameter.inner') end";
          options.desc = "swap previous parameter";
        }
      ];
    };
  };
}
