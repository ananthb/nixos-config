# Dev Environment

The `dev` home-manager module is a single import that delivers a complete day-to-day environment: fish + starship + a zellij/yazi workspace via [yazelix], nixvim with 30+ plugins, and the usual CLI sidekicks (atuin, bat, eza, fd, fzf, gh, glab, gpg, lazygit, ripgrep, zoxide, delta). Personal identity (git user, ssh keys, sops) lives in your own config — `dev` provides the tooling, not the secrets.

[yazelix]: https://github.com/luccahuguet/yazelix

## Terminal multiplexer (zellij via yazelix)

Yazelix wires zellij + yazi into a single workspace where the file manager and shell panes coexist. There's no tmux anymore.

| Action | Default keybinding |
|--------|-------------------|
| Open file picker | yazelix's `y` from any pane (or run `y` for yazi standalone) |
| Edit a file from yazi | `Enter` — opens in nvim, or routes to a shared zellij `nvim` pane if one is open |
| New pane / split | zellij's `Ctrl+p` then a direction key |
| Detach session | `Ctrl+o d` |
| Quit session | `Ctrl+q` |

Configuration lives upstream in [yazelix's docs][yazelix-keys] — the dev module just `enable`s it with `terminal = "ghostty"` and binds yazi/lazygit/helix to host (non-flake) versions for speed.

[yazelix-keys]: https://github.com/luccahuguet/yazelix#default-keybindings

## Shell (fish)

Fish is enabled with empty greeting, atuin for history search, zoxide for `cd`, and yazelix integration. There are no fixed abbreviations baked in by the module — add your own in your personal config if you want them.

Starship prompt shows: `[ssh:host] dir [git_branch][git_status] (nix) (k8s/ctx) (cmd_duration) >`

- **Hostname** only when SSH'd in (`ssh:` prefix).
- **Directory** truncated to 3 segments, clamped to repo root.
- **Git status** is `[$ahead_behind$modified]` inline with the branch.
- **Nix shell** marker shows when you're inside `nix develop` / `nix shell`.
- **Kubernetes** context/namespace, when the current dir matches a kube-related path.
- **Command duration** only for commands ≥ 2s.
- **Prompt char** is `>` — green on success, red on the last non-zero exit.

## File manager (yazi)

Yazi opens via `y` (shell wrapper) or from within yazelix. Defaults: hidden files visible, natural sort, directories first.

Press `Enter` on a text-ish file and it opens in `nvim` — or hands off to an existing zellij `nvim` pane if one's already running (the rule is in `mgr.opener.edit`).

## Neovim (nixvim)

Leader key is **Space**. The full plugin and LSP set is in `modules/home/dev.nix` — the highlights below.

### File navigation

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

### Harpoon (quick file switching)

Pin up to 4 files for instant access:

| Key | Action |
|-----|--------|
| `Space ha` | Add current file to harpoon |
| `Space hh` | Toggle harpoon quick menu |
| `Space h1`–`Space h4` | Jump to harpoon file 1–4 |

### Flash (jump anywhere)

Press `s` then type 2 characters to jump to any visible match. Labels appear on matches — type the label to jump.

### LSP

| Key | Action |
|-----|--------|
| `Space gd` | Go to definition |
| `Space gr` | List references |
| `Space gI` | Go to implementation |
| `Space gt` | Go to type definition |
| `Space fs` | Document symbols |
| `Space fd` | Diagnostics |

Diagnostics float automatically on `CursorHold`. Inlay hints are enabled.

Enabled language servers: bash, C/C++ (clangd), CSS, Docker, Go, HTML, LaTeX (ltex), Lua, Markdown, Nix (nil), Python (pyright), Rust (rust-analyzer), Terraform, TypeScript, YAML, Zig.

### Treesitter text objects

Select, move between, and swap code structures.

Selection (visual mode):

| Key | Selects |
|-----|---------|
| `vaf` / `vif` | Around/inside function |
| `vac` / `vic` | Around/inside class |
| `vaa` / `via` | Around/inside parameter |
| `vai` / `vii` | Around/inside conditional |
| `val` / `vil` | Around/inside loop |

Movement:

| Key | Jumps to |
|-----|----------|
| `]f` / `[f` | Next/previous function start |
| `]F` / `[F` | Next/previous function end |
| `]c` / `[c` | Next/previous class start |
| `]a` / `[a` | Next/previous parameter |

Swap:

| Key | Action |
|-----|--------|
| `Space sa` | Swap parameter with next |
| `Space sA` | Swap parameter with previous |

### Surround

| Key | Action | Example |
|-----|--------|---------|
| `ys{motion}{char}` | Add surround | `ysiw"` wraps word in quotes |
| `cs{old}{new}` | Change surround | `cs"'` changes `"` to `'` |
| `ds{char}` | Delete surround | `ds"` removes surrounding quotes |

### Other features

| Key | Action |
|-----|--------|
| `Space u` | Toggle undotree (persistent undo history across sessions) |
| `Space fq` | Quickfix list |
| `Space fr` | Registers |
| `Space f'` | Marks |
| `Space fh` | Help tags |

### Formatting on save

Conform-nvim with LSP fallback:

| Language | Formatters |
|----------|-----------|
| Go | gofmt, goimports |
| Python | isort, black |
| Terraform/HCL | terraform_fmt, hclfmt |
| Nix | alejandra |
| Lua | stylua |
| YAML | yamlfix |
| Other | trim_whitespace |

### Copilot

GitHub Copilot is wired through `copilot-cmp` (completion menu), not ghost text. Suggestions appear alongside LSP completions.

## Git

Configured with delta for side-by-side diffs, absorb, histogram diff algorithm, zdiff3 merge style, and rerere. The module does **not** set `user.name` or `user.email` — add those in your own config:

```nix
programs.git.settings.user = {
  name = "Your Name";
  email = "you@example.com";
};
```
