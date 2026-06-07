# Home Manager Modules

## shell

A minimal bash baseline: large dedup'd history, sensible shell options (`histappend`, `checkwinsize`, `extglob`, `globstar`, `checkjobs`), and a handful of aliases (`ll`, `la`, `gs`, `gd`, `gl`). Import this if you want a slightly nicer login shell on hosts that don't run the full dev environment.

## dev

The full day-to-day environment: fish + starship + a yazelix-driven zellij/yazi workspace, nixvim with 30+ plugins (LSP for ~15 languages, treesitter + textobjects, telescope, harpoon, oil, flash, surround, copilot, DAP, conform), and CLI tools (atuin, bat, eza, fd, fzf, gh, glab, gpg, lazygit, ripgrep, zoxide, delta).

The dev module does **not** set git identity, ssh keys, or any sops wiring — those belong in your personal config. See [Dev Environment](../guides/dev.md) for the keymap reference.

## options

Declares `machines.username` for home-manager modules. Imported automatically by `default`.

## default

Aggregator: `options` + `shell` + `dev`.
