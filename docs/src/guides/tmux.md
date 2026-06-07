# Tmux Setup

Prefix key is **Ctrl+a**. Vi keybindings are enabled.

## Session management

| Key | Action |
|-----|--------|
| `prefix d` | Detach from session |
| `prefix s` | List sessions |
| `prefix $` | Rename session |

Sessions auto-save every 10 minutes via **continuum** and restore on tmux start via **resurrect**.

## Windows and panes

| Key | Action |
|-----|--------|
| `prefix c` | New window (inherits current path) |
| `prefix \|` | Split vertical (inherits current path) |
| `prefix -` | Split horizontal (inherits current path) |
| `prefix n` / `prefix p` | Next/previous window |
| `prefix 0-9` | Jump to window by number |

### Pane navigation (vim-tmux-navigator)

Seamlessly navigate between vim splits and tmux panes:

| Key | Action |
|-----|--------|
| `Ctrl+h` | Move left |
| `Ctrl+j` | Move down |
| `Ctrl+k` | Move up |
| `Ctrl+l` | Move right |

These work identically whether you're in a vim split or a tmux pane.

### Pane resizing

| Key | Action |
|-----|--------|
| `prefix H` | Resize left (repeatable) |
| `prefix J` | Resize down (repeatable) |
| `prefix K` | Resize up (repeatable) |
| `prefix L` | Resize right (repeatable) |

## Copy mode

Enter copy mode with `prefix [`, then use vi keys to navigate.

| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `y` | Yank (copies to system clipboard via tmux-yank) |
| `q` | Exit copy mode |

## Tmux Thumbs

Press `prefix F` to highlight all copyable text on screen (URLs, file paths, hashes, etc.). Type the hint character to copy the match to the system clipboard.

## Theme

Catppuccin Mocha with rounded window status.

## Status bar

- **Left**: `[session-name]`
- **Right**: current time, with `PREFIX` indicator when prefix is active

## Configuration

- History limit: 100,000 lines
- Mouse: enabled
- True color: enabled (`tmux-256color` with RGB override)
- Escape time: 0ms (no delay after pressing Escape)
