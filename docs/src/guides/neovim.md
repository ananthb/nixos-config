# Neovim Setup

The dev module configures Neovim via nixvim with 30+ plugins. Leader key is **Space**.

## File navigation

| Key | Action |
|-----|--------|
| `-` | Open parent directory (oil.nvim file explorer) |
| `q` | Close oil buffer |
| `Ctrl+s` | Open file in vertical split (in oil) |
| `Space ff` | Find files (telescope) |
| `Space fl` | Live grep across project |
| `Space fB` | Switch buffers |
| `Space fo` | Recent files |
| `Space fb` | File browser (telescope) |
| `Space f/` | Fuzzy find in current buffer |
| `Space f<CR>` | Resume last telescope search |

## Harpoon (quick file switching)

Pin up to 4 files for instant access:

| Key | Action |
|-----|--------|
| `Space ha` | Add current file to harpoon |
| `Space hh` | Toggle harpoon quick menu |
| `Space h1` | Jump to harpoon file 1 |
| `Space h2` | Jump to harpoon file 2 |
| `Space h3` | Jump to harpoon file 3 |
| `Space h4` | Jump to harpoon file 4 |

## Flash (jump anywhere)

Press `s` then type 2 characters to jump to any visible match. Labels appear on matches — type the label to jump.

## LSP

| Key | Action |
|-----|--------|
| `Space gd` | Go to definition |
| `Space gr` | List references |
| `Space gI` | Go to implementation |
| `Space gt` | Go to type definition |
| `Space fs` | Document symbols |
| `Space fd` | Diagnostics |

Diagnostics float automatically on `CursorHold`. Inlay hints are enabled.

### Language servers

Enabled out of the box: bash, C/C++ (clangd), CSS, Docker, Go, HTML, LaTeX (ltex), Lua, Markdown, Nix (nil), Python (pyright), Rust (rust-analyzer), Terraform, TypeScript, YAML, Zig.

## Treesitter text objects

Select, move between, and swap code structures:

### Selection (visual mode)
| Key | Selects |
|-----|---------|
| `vaf` / `vif` | Around/inside function |
| `vac` / `vic` | Around/inside class |
| `vaa` / `via` | Around/inside parameter |
| `vai` / `vii` | Around/inside conditional |
| `val` / `vil` | Around/inside loop |

### Movement
| Key | Jumps to |
|-----|----------|
| `]f` / `[f` | Next/previous function start |
| `]F` / `[F` | Next/previous function end |
| `]c` / `[c` | Next/previous class start |
| `]a` / `[a` | Next/previous parameter |

### Swap
| Key | Action |
|-----|--------|
| `Space sa` | Swap parameter with next |
| `Space sA` | Swap parameter with previous |

## Surround

| Key | Action | Example |
|-----|--------|---------|
| `ys{motion}{char}` | Add surround | `ysiw"` wraps word in quotes |
| `cs{old}{new}` | Change surround | `cs"'` changes `"` to `'` |
| `ds{char}` | Delete surround | `ds"` removes surrounding quotes |

## Other features

| Key | Action |
|-----|--------|
| `Space u` | Toggle undotree (persistent undo history across sessions) |
| `Space fq` | Quickfix list |
| `Space fr` | Registers |
| `Space f'` | Marks |
| `Space fh` | Help tags |

## Formatting

Auto-formats on save via conform-nvim with LSP fallback:

| Language | Formatters |
|----------|-----------|
| Go | gofmt, goimports |
| Python | isort, black |
| Terraform/HCL | terraform_fmt, hclfmt |
| Nix | alejandra |
| Lua | stylua |
| YAML | yamlfix |
| Other | trim_whitespace |

## Copilot

GitHub Copilot is integrated through `copilot-cmp` (completion menu), not ghost text. Suggestions appear alongside LSP completions.
