# Shell Setup

The shell module provides fish + starship + tmux + zoxide + atuin + eza + bat + fd.

## Starship prompt

The prompt shows: `hostname directory git_branch git_status nix_shell kubernetes cmd_duration`

- **Hostname** only appears when SSH'd into a machine (prefixed with `ssh:`)
- **Directory** truncates to 3 segments (or repo root)
- **Git status** shows branch and `[ahead/behind/modified]` indicators
- **Nix shell** shows `nix` when in a nix develop/shell
- **Kubernetes** shows current context/namespace
- **Command duration** appears for commands taking >2 seconds
- **Character** is `>` — green on success, red on error

## Fish abbreviations

Type the short form and it expands inline (not an alias — you see the full command before running it):

### Git
| Abbr | Expands to |
|------|-----------|
| `g` | `git` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gca` | `git commit --amend` |
| `gco` | `git checkout` |
| `gd` | `git diff` |
| `gds` | `git diff --staged` |
| `gl` | `git log --oneline` |
| `gp` | `git push` |
| `gpf` | `git push --force-with-lease` |
| `gr` | `git rebase` |
| `gs` | `git status -sb` |
| `gsw` | `git switch` |

### Docker
| Abbr | Expands to |
|------|-----------|
| `dc` | `docker compose` |
| `dcu` | `docker compose up -d` |
| `dcd` | `docker compose down` |
| `dcl` | `docker compose logs -f` |

### Nix
| Abbr | Expands to |
|------|-----------|
| `nr` | `nix run` |
| `ns` | `nix shell` |
| `nb` | `nix build` |
| `nf` | `nix flake` |
| `nd` | `nix develop` |

### Other
| Abbr | Expands to |
|------|-----------|
| `k` | `kubectl` |
| `tf` | `terraform` |
| `lg` | `lazygit` |
| `v` | `nvim` |
| `cat` | `bat` |

## Zoxide

Smart `cd` replacement that learns your most-used directories.

```bash
z machines     # jump to most-used dir matching "machines"
z src m        # jump to best match for "src" then "m"
zi             # interactive fuzzy picker
```

Zoxide scores directories by frequency and recency. The more you visit a path, the higher it ranks.

## Atuin

Searchable shell history with sync support.

- **Ctrl+R** — fuzzy search history (compact view, 20-line inline preview)
- **Up arrow** — also searches history
- **Enter** — accepts the selected command immediately

## Eza

Modern `ls` replacement. Automatically aliased via fish integration:

- `ls` shows files with git status indicators and icons
- `ll` shows long format
- `la` shows all files including hidden
- `lt` shows tree view
- `tree` shows tree view

## Bat

Syntax-highlighted file viewer. Aliased as `cat` via fish abbreviation.

Uses the `base16-256` theme for consistent colors across terminals.

## fd

Fast file finder (alternative to `find`). Respects `.gitignore` by default.

```bash
fd pattern           # find files matching pattern
fd -e nix            # find .nix files
fd -t d config       # find directories matching "config"
```
