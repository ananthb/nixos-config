# Home Manager Modules

## shell

A batteries-included shell environment. Provides:

- **Fish** shell with abbreviations for git, docker compose, kubectl, nix, and more
- **Starship** prompt showing directory, git branch/status, nix shell, k8s context, command duration, and SSH hostname
- **Tmux** with vi mode, catppuccin theme, vim-tmux-navigator, resurrect/continuum, and thumbs
- **Zoxide** — smart `cd` that learns your directories
- **Atuin** — searchable shell history with compact UI
- **Eza** — modern `ls` replacement with git status and icons
- **Bat** — syntax-highlighted `cat`
- **fd** — fast file finder

See [Shell Setup](../guides/shell.md) for detailed usage.

## dev

A full Neovim IDE and git configuration. Provides:

- **Nixvim** with 30+ plugins: LSP (15 language servers), treesitter with textobjects, telescope, harpoon, oil, flash, surround, copilot, DAP, and more
- **Git** with delta (side-by-side diffs), absorb, histogram diff, zdiff3 merge, rerere
- **Direnv** with nix-direnv integration
- **GPG** with Yubikey/smartcard support

Note: this module does **not** set `git.settings.user.name` or `git.settings.user.email`. Set those in your own config:

```nix
programs.git.settings.user = {
  name = "Your Name";
  email = "you@example.com";
};
```

See [Neovim Setup](../guides/neovim.md) for detailed keybindings.

## options

Declares `machines.username` for home-manager modules. Imported automatically by `default`.
