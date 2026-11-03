# Neovim: one Nix-defined config, with the language tooling split into a
# catalog so hosts can drop what they never edit -- see dev.neovim.disable in
# home/chromebook.nix.
#
# The catalog is the shape the previous editor module used, kept because it
# is the part worth keeping: one entry per language group, merged across
# entries, and filtered by the consuming host before anything is installed.
# A disabled entry takes its language servers, formatters, linters, treesitter
# parsers and packages with it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrValues
    concatLists
    concatMap
    elem
    filter
    filterAttrs
    foldl'
    mapAttrs
    mkOption
    removeAttrs
    types
    unique
    zipAttrsWith
    ;

  cfg = config.dev.neovim;

  # One entry per language group.
  #
  #   packages   tools that must be on PATH. These go in home.packages rather
  #              than only into nixvim's wrapper, so they are available to
  #              shell pipelines and to `goimports`-style tools the editor
  #              shells out to.
  #   servers    nvim-lspconfig server name -> config passed to
  #              vim.lsp.config().
  #   formatters filetype -> conform.nvim formatter names, merged across
  #              entries.
  #   linters    filetype -> nvim-lint linter names, merged across entries.
  #              nvim-lint runs them on BufWritePost, matching the on-save
  #              behaviour the previous editor had.
  #   parsers    nvim-treesitter grammar names to install.
  catalog = {
    bash = {
      packages = [pkgs.bash-language-server pkgs.shellcheck pkgs.shfmt];
      # bash-language-server shells out to shellcheck itself, so the linter
      # only needs a place on PATH.
      servers.bashls = {};
      formatters.bash = ["shfmt"];
      parsers = ["bash"];
    };

    c = {
      packages = [pkgs.clang-tools pkgs.lldb];
      servers.clangd = {};
      formatters = {
        c = ["clang-format"];
        cpp = ["clang-format"];
      };
      parsers = ["c" "cpp"];
    };

    css = {
      packages = [pkgs.vscode-langservers-extracted];
      servers.cssls = {};
      parsers = ["css"];
    };

    docker = {
      packages = [pkgs.dockerfile-language-server-nodejs];
      servers.dockerls = {};
      parsers = ["dockerfile"];
    };

    elm = {
      packages = [
        pkgs.elmPackages.elm
        pkgs.elmPackages.elm-format
        pkgs.elmPackages.elm-language-server
      ];
      servers.elmls = {};
      formatters.elm = ["elm-format"];
      parsers = ["elm"];
    };

    go = {
      packages = [pkgs.go pkgs.gopls pkgs.gotools pkgs.golangci-lint pkgs.delve];
      servers.gopls = {};
      formatters.go = ["goimports"];
      linters.go = ["golangcilint"];
      parsers = ["go" "gomod" "gosum"];
    };

    html = {
      packages = [pkgs.vscode-langservers-extracted];
      servers.html = {};
      parsers = ["html"];
    };

    lua = {
      packages = [pkgs.lua-language-server pkgs.stylua];
      servers.lua_ls = {
        settings.Lua.telemetry.enable = false;
      };
      formatters.lua = ["stylua"];
      parsers = ["lua" "luadoc"];
    };

    markdown = {
      packages = [pkgs.marksman];
      servers.marksman = {};
      parsers = ["markdown" "markdown_inline"];
    };

    nix = {
      packages = [pkgs.nil pkgs.alejandra];
      servers.nil_ls = {};
      formatters.nix = ["alejandra"];
      parsers = ["nix"];
    };

    python = {
      packages = [pkgs.pyright pkgs.isort pkgs.black pkgs.mypy pkgs.pylint];
      servers.pyright = {};
      formatters.python = ["isort" "black"];
      linters.python = ["mypy" "pylint"];
      parsers = ["python"];
    };

    rust = {
      packages = [pkgs.rust-analyzer pkgs.rustc pkgs.cargo pkgs.rustfmt pkgs.lldb];
      servers.rust_analyzer = {};
      formatters.rust = ["rustfmt"];
      parsers = ["rust"];
    };

    terraform = {
      packages = [pkgs.terraform-ls pkgs.hclfmt pkgs.tfsec];
      servers.terraformls = {};
      # hclfmt covers Terraform, HCL and tfvars without pulling in the unfree
      # terraform binary just to format.
      formatters = {
        terraform = ["hcl"];
        hcl = ["hcl"];
        tfvars = ["hcl"];
      };
      linters = {
        terraform = ["tfsec"];
        hcl = ["tfsec"];
      };
      parsers = ["hcl" "terraform"];
    };

    yaml = {
      packages = [pkgs.yaml-language-server pkgs.yamlfix pkgs.yamllint];
      servers.yamlls = {};
      formatters.yaml = ["yamlfix"];
      linters.yaml = ["yamllint"];
      parsers = ["yaml"];
    };
  };

  active = attrValues (removeAttrs catalog cfg.disable);

  # --- Language servers ----------------------------------------------------
  servers = foldl' (acc: entry: acc // (entry.servers or {})) {} active;

  # --- Formatters ----------------------------------------------------------
  # `_` is conform's catch-all: trim trailing whitespace even in filetypes
  # that have no real formatter, which is what the previous editor did.
  formattersByFt =
    zipAttrsWith (_: concatLists) (map (e: e.formatters or {}) active)
    // {
      "_" = ["trim_whitespace"];
    };

  # --- Linters -------------------------------------------------------------
  lintByFt =
    filterAttrs (_: names: names != [])
    (mapAttrs (_: names: filter (name: !(elem name cfg.disableLinters)) names)
      (zipAttrsWith (_: concatLists) (map (e: e.linters or {}) active)));

  # --- Treesitter ----------------------------------------------------------
  # Parsers the editor itself needs, regardless of which languages are on.
  baseParsers = [
    "comment"
    "diff"
    "editorconfig"
    "fish"
    "gitcommit"
    "gitignore"
    "json"
    "json5"
    "kdl"
    "query"
    "regex"
    "toml"
    "vim"
    "vimdoc"
  ];

  parserNames = unique (baseParsers ++ concatMap (e: e.parsers or []) active);

  # Grammar attribute names come from nixpkgs, so filtering by name keeps a
  # catalog entry from breaking evaluation if a grammar is renamed upstream.
  grammarPackages =
    attrValues (filterAttrs (name: _: elem name parserNames)
      config.programs.nixvim.plugins.treesitter.package.builtGrammars);

  selectTextObject = key: query: desc: {
    mode = ["x" "o"];
    inherit key;
    action.__raw = ''function() require("nvim-treesitter-textobjects.select").select_textobject("${query}", "textobjects") end'';
    options.desc = desc;
  };

  moveTextObject = key: move: query: desc: {
    mode = ["n" "x" "o"];
    inherit key;
    action.__raw = ''function() require("nvim-treesitter-textobjects.move").${move}("${query}", "textobjects") end'';
    options.desc = desc;
  };
in {
  options.dev.neovim = {
    disable = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["rust" "c"];
      description = ''
        Language catalog entries to leave out on this host. Drops the entry's
        language servers, formatters, linters, treesitter parsers and packages.
      '';
    };

    disableLinters = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["tfsec"];
      description = ''
        nvim-lint linters to leave out, named by their nvim-lint linter name.
        For dropping a single linter while keeping its language.
      '';
    };
  };

  config = {
    home.packages = concatMap (e: e.packages) active;

    programs.nixvim = {
      enable = true;
      # Owns EDITOR and VISUAL for external tools. No per-host home/*.nix
      # file needs to set them.
      defaultEditor = true;
      vimdiffAlias = true;

      # Reuse the host's already-instantiated nixpkgs (including its unfree
      # allowlist) instead of letting nixvim import a second copy.
      nixpkgs.pkgs = pkgs;

      globals = {
        mapleader = " ";
        maplocalleader = " ";
        # Keep Neovim's per-filetype ftplugin mappings from shadowing the
        # treesitter textobjects below.
        no_plugin_maps = true;
      };

      opts = {
        number = true;
        relativenumber = true;
        cursorline = true;
        scrolloff = 8;
        signcolumn = "yes";
        updatetime = 300;
        undofile = true;
        swapfile = false;
        splitright = true;
        splitbelow = true;
        termguicolors = true;
        mouse = "a";

        expandtab = true;
        shiftwidth = 2;
        tabstop = 2;
        softtabstop = 2;
        smartindent = true;

        ignorecase = true;
        smartcase = true;
        incsearch = true;
        inccommand = "split";
        completeopt = "menu,menuone,noselect";
        pumheight = 12;
        winborder = "rounded";
        wrap = false;
      };

      clipboard = {
        register = "unnamedplus";
        providers = {
          wl-copy.enable = pkgs.stdenv.hostPlatform.isLinux;
          pbcopy.enable = pkgs.stdenv.hostPlatform.isDarwin;
        };
      };

      colorschemes.oxocarbon.enable = true;

      diagnostic.settings = {
        virtual_text = {
          spacing = 2;
          prefix = "●";
        };
        severity_sort = true;
        update_in_insert = false;
        float = {
          border = "rounded";
          source = "if_many";
        };
      };

      lsp = {
        inlayHints.enable = true;
        servers =
          mapAttrs (_: serverConfig: {
            enable = true;
            config = serverConfig;
          })
          servers;
        keymaps = [
          {
            key = "gd";
            lspBufAction = "definition";
          }
          {
            key = "gD";
            lspBufAction = "declaration";
          }
          {
            key = "gr";
            lspBufAction = "references";
          }
          {
            key = "gI";
            lspBufAction = "implementation";
          }
          {
            key = "gy";
            lspBufAction = "type_definition";
          }
          {
            key = "K";
            lspBufAction = "hover";
          }
          {
            key = "<leader>rn";
            lspBufAction = "rename";
          }
          {
            key = "<leader>ca";
            lspBufAction = "code_action";
          }
        ];
      };

      plugins = {
        # nvim-lspconfig supplies the default cmd/filetypes/root-markers for
        # the servers enabled above; it must be installed for vim.lsp.enable()
        # to find them.
        lspconfig.enable = true;

        lualine.enable = true;
        bufferline.enable = true;

        which-key = {
          enable = true;
          # A large centered popup. Space is still the leader, so the old
          # key sequences keep working, but the menu is not trying to be the
          # editor we just left.
          settings = {
            preset = "modern";
            spec = [
              {
                __unkeyed-1 = "<leader>b";
                group = "Buffers";
              }
              {
                __unkeyed-1 = "<leader>c";
                group = "Code";
              }
              {
                __unkeyed-1 = "<leader>f";
                group = "Find";
              }
              {
                __unkeyed-1 = "<leader>g";
                group = "Git";
              }
              {
                __unkeyed-1 = "<leader>s";
                group = "Swap";
              }
              {
                __unkeyed-1 = "<leader>u";
                group = "UI";
              }
              {
                __unkeyed-1 = "<leader>x";
                group = "Diagnostics";
              }
            ];
          };
        };

        mini-icons = {
          enable = true;
          settings.mock_nvim_web_devicons = true;
        };

        gitsigns.enable = true;

        oil = {
          enable = true;
          settings = {
            view_options.show_hidden = true;
            skip_confirm_for_simple_edits = true;
          };
        };

        fzf-lua = {
          enable = true;
          keymaps = {
            "<leader>ff" = "files";
            "<leader>fg" = "live_grep";
            "<leader>/" = "live_grep";
            "<leader>fw" = "grep_cword";
            "<leader>fb" = "buffers";
            "<leader>fr" = "oldfiles";
            "<leader>fh" = "help_tags";
            "<leader>fd" = "diagnostics_document";
            "<leader>fs" = "lsp_document_symbols";
            "<leader>gc" = "git_commits";
            "<leader>gb" = "git_branches";
            "<leader>gs" = "git_status";
          };
        };

        treesitter = {
          enable = true;
          highlight.enable = true;
          indent.enable = true;
          folding.enable = true;
          inherit grammarPackages;
        };

        treesitter-textobjects = {
          enable = true;
          settings = {
            select.lookahead = true;
            move.set_jumps = true;
          };
        };

        conform-nvim = {
          enable = true;
          settings = {
            format_on_save = {
              timeout_ms = 1000;
              lsp_format = "fallback";
            };
            formatters_by_ft = formattersByFt;
          };
        };

        lint = {
          enable = lintByFt != {};
          lintersByFt = lintByFt;
        };

        blink-cmp = {
          enable = true;
          settings = {
            keymap.preset = "super-tab";
            sources.default = ["lsp" "path" "buffer"];
            completion = {
              documentation.auto_show = true;
              accept.auto_brackets.enabled = true;
            };
            signature.enabled = true;
            appearance.nerd_font_variant = "mono";
          };
        };

        nvim-autopairs.enable = true;
        nvim-surround.enable = true;

        flash.enable = true;
        illuminate.enable = true;
        todo-comments.enable = true;
        trouble.enable = true;
      };

      keymaps = [
        {
          key = "-";
          action = "<cmd>Oil<cr>";
          options.desc = "Open parent directory";
        }

        # Diagnostic navigation, using Neovim's own jump API.
        {
          key = "]d";
          action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true }) end";
          options.desc = "Next diagnostic";
        }
        {
          key = "[d";
          action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true }) end";
          options.desc = "Previous diagnostic";
        }
        {
          key = "gl";
          action.__raw = "function() vim.diagnostic.open_float({ scope = 'line' }) end";
          options.desc = "Line diagnostics";
        }

        # Trouble lists.
        {
          key = "<leader>xx";
          action = "<cmd>Trouble diagnostics toggle<cr>";
          options.desc = "Diagnostics";
        }
        {
          key = "<leader>xX";
          action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
          options.desc = "Buffer diagnostics";
        }
        {
          key = "<leader>xs";
          action = "<cmd>Trouble symbols toggle focus=false<cr>";
          options.desc = "Symbols";
        }
        {
          key = "<leader>xl";
          action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
          options.desc = "LSP references";
        }
        {
          key = "<leader>xq";
          action = "<cmd>Trouble qflist toggle<cr>";
          options.desc = "Quickfix";
        }

        {
          key = "<leader>cf";
          action.__raw = "function() require('conform').format({ async = true, lsp_format = 'fallback' }) end";
          options.desc = "Format buffer";
        }

        # Gitsigns: the parts worth a keybinding. The picker entries for
        # status/branches/commits live under plugins.fzf-lua above.
        {
          key = "]h";
          action.__raw = "function() require('gitsigns').nav_hunk('next') end";
          options.desc = "Next hunk";
        }
        {
          key = "[h";
          action.__raw = "function() require('gitsigns').nav_hunk('prev') end";
          options.desc = "Previous hunk";
        }
        {
          key = "<leader>gp";
          action.__raw = "function() require('gitsigns').preview_hunk() end";
          options.desc = "Preview hunk";
        }
        {
          key = "<leader>gB";
          action.__raw = "function() require('gitsigns').blame_line({ full = true }) end";
          options.desc = "Blame line";
        }
        {
          key = "<leader>gS";
          action.__raw = "function() require('gitsigns').stage_hunk() end";
          options.desc = "Stage hunk";
        }
        {
          key = "<leader>gr";
          action.__raw = "function() require('gitsigns').reset_hunk() end";
          options.desc = "Reset hunk";
        }

        {
          key = "<leader>uh";
          action.__raw = "function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end";
          options.desc = "Toggle inlay hints";
        }

        # Treesitter textobjects: select.
        (selectTextObject "af" "@function.outer" "Around function")
        (selectTextObject "if" "@function.inner" "Inner function")
        (selectTextObject "ac" "@class.outer" "Around class")
        (selectTextObject "ic" "@class.inner" "Inner class")
        (selectTextObject "aa" "@parameter.outer" "Around parameter")
        (selectTextObject "ia" "@parameter.inner" "Inner parameter")
        (selectTextObject "ai" "@conditional.outer" "Around conditional")
        (selectTextObject "ii" "@conditional.inner" "Inner conditional")
        (selectTextObject "al" "@loop.outer" "Around loop")
        (selectTextObject "il" "@loop.inner" "Inner loop")

        # Treesitter textobjects: move.
        (moveTextObject "]f" "goto_next_start" "@function.outer" "Next function start")
        (moveTextObject "]c" "goto_next_start" "@class.outer" "Next class start")
        (moveTextObject "]a" "goto_next_start" "@parameter.inner" "Next parameter")
        (moveTextObject "]F" "goto_next_end" "@function.outer" "Next function end")
        (moveTextObject "]C" "goto_next_end" "@class.outer" "Next class end")
        (moveTextObject "[f" "goto_previous_start" "@function.outer" "Previous function start")
        (moveTextObject "[c" "goto_previous_start" "@class.outer" "Previous class start")
        (moveTextObject "[a" "goto_previous_start" "@parameter.inner" "Previous parameter")
        (moveTextObject "[F" "goto_previous_end" "@function.outer" "Previous function end")
        (moveTextObject "[C" "goto_previous_end" "@class.outer" "Previous class end")

        # Treesitter textobjects: swap.
        {
          key = "<leader>sa";
          action.__raw = ''function() require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner") end'';
          options.desc = "Swap next parameter";
        }
        {
          key = "<leader>sA";
          action.__raw = ''function() require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner") end'';
          options.desc = "Swap previous parameter";
        }
      ];

      extraConfigLua = ''
        -- Terraform's .nomad files are HCL-shaped; this used to be built in,
        -- Neovim needs it spelled out.
        vim.filetype.add({ extension = { nomad = "hcl" } })
      '';
    };
  };
}
