# Moonlander keymap

> Generated from `keymap/keymap.c` and `keymap/colours.h` by `generate-readme.py`.
> Run `nix shell nixpkgs#python3 --command python3 keyboards/moonlander/generate-readme.py` from the repository root after changing the keymap.

The key names are shown left-to-right for each hand. `Transparent` means the key falls through to a lower active layer.
For tap/hold keys, the first action is on tap and the second is on hold.

### Layer 0: Base

**Lighting:** animated RGB effect

| Physical row | Left half | Right half |
| --- | --- | --- |
| Number row | Esc · 1 · 2 · 3 · 4 · 5 · ~ | Volume + · 6 · 7 · 8 · 9 · 0 · Backspace |
| QWERTY row | Caps Word toggle · Q · W · E · R · T · RGB on/off | Volume − / mute · Y · U · I · O · P · - |
| Home row | Tab · A / Shift · S · D · F · G · Page Down | Page Up · H · J · K · L · ; / Shift · ' |
| Bottom row | Enter / Shift · Z / Cmd · X · C · V · B | N · M · , · . · Slash / Cmd · Enter / Shift |
| Inner/thumb row | Ctrl · Hold/tap-toggle: Function & numpad · Option · Cmd · Hold: Symbols · Cmd+C | Cmd+V · Hold/tap-toggle: Navigation & mouse · Cmd · Option · Toggle: Function & numpad · Ctrl |
| Thumbs | Space / Shift · Enter / Cmd · Hold/tap-toggle: Symbols | Delete word · Enter / Cmd · Backspace |

### Layer 1: Symbols

**Lighting:** Amber, Cream, Ember, Sky

| Physical row | Left half | Right half |
| --- | --- | --- |
| Number row | Esc · Transparent · Transparent · Transparent · Transparent · Transparent · Transparent | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent · Backspace |
| QWERTY row | Transparent · ! · @ · { · } · & · Transparent | Transparent · Transparent · \| · ` · ~ · \ · Transparent |
| Home row | Tab · # / Shift · $ · ( · ) · * · Transparent | Transparent · Transparent · + · - · = · ; / Shift · ' |
| Bottom row | Shift · % / Cmd · ^ · [ · ] · Transparent | Transparent · _ · , · . · Slash / Cmd · Shift |
| Inner/thumb row | Transparent · Transparent · Transparent · Cmd · Transparent · Transparent | Transparent · Hold: Function & numpad · Cmd · Transparent · Transparent · Transparent |
| Thumbs | Transparent · Transparent · Transparent | Transparent · Transparent · Transparent |

### Layer 2: Navigation & mouse

**Lighting:** Cream, Magenta, Orchid, Plum, Red, Rose, Teal

| Physical row | Left half | Right half |
| --- | --- | --- |
| Number row | Transparent · F1 · F2 · F3 · F4 · F5 · Transparent | Transparent · F6 · F7 · F8 · F9 · F10 · F11 |
| QWERTY row | Transparent · Transparent · Transparent · Mouse ↑ · Wheel ↑ · Transparent · Transparent | Transparent · Transparent · Transparent · ↑ · Transparent · Transparent · F12 |
| Home row | Transparent · Shift · Mouse ← · Mouse ↓ · Mouse → · Transparent · Transparent | Transparent · Transparent · ← · ↓ · → · Shift · Transparent |
| Bottom row | Transparent · Cmd · Wheel ← · Wheel → · Wheel ↓ · Mouse 2 | Transparent · Transparent · Transparent · Transparent · Cmd · Transparent |
| Inner/thumb row | Ctrl · Transparent · Transparent · Transparent · Mouse 1 · Next RGB effect | RGB on/off · Transparent · Transparent · Transparent · Transparent · Ctrl |
| Thumbs | Mouse 1 · Mouse 2 · Transparent | LED brightness · Dim RGB · Brighten RGB |

### Layer 3: Function & numpad

**Lighting:** Amber, Green, Orchid, Sky

| Physical row | Left half | Right half |
| --- | --- | --- |
| Number row | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent · Transparent | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent · Transparent |
| QWERTY row | Transparent · F1 · F2 · F3 · F4 · F5 · F6 | Cmd · Transparent · Transparent · Transparent · Transparent · Transparent · Transparent |
| Home row | Transparent · 1 · 2 · 3 · 4 · 5 · Transparent | Transparent · 6 · 7 · 8 · 9 · 0 · Transparent |
| Bottom row | Transparent · Delete to line start · Reopen tab · Markdown link · Transparent · Transparent | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent |
| Inner/thumb row | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent | Transparent · Transparent · Transparent · Transparent · Transparent · Transparent |
| Thumbs | Transparent · Transparent · Transparent | Transparent · Transparent · Transparent |

## Custom actions

| Key label | Action |
| --- | --- |
| Delete word | Option+Backspace |
| Markdown link | Types `[]()` and leaves the cursor between the brackets |
| Reopen tab | Cmd+Shift+T |
| Delete to line start | Cmd+Backspace |
| Volume − / mute | Tap for volume down; double-tap for mute |
| `# / Shift` | Tap for `#`; hold for Shift |
| `% / Cmd` | Tap for `%`; hold for Cmd |
