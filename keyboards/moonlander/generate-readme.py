#!/usr/bin/env python3
"""Generate the Moonlander keymap reference from the QMK source files."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
KEYMAP = HERE / "keymap" / "keymap.c"
COLOURS = HERE / "keymap" / "colours.h"
README = HERE / "README.md"

LAYOUT_ROWS = (
    ("Number row", 14, 7),
    ("QWERTY row", 14, 7),
    ("Home row", 14, 7),
    ("Bottom row", 12, 6),
    ("Inner/thumb row", 12, 6),
    ("Thumbs", 6, 3),
)

LAYER_NAMES = {
    0: "Base",
    1: "Symbols",
    2: "Navigation & mouse",
    3: "Function & numpad",
}

SPECIAL_KEYS = {
    "KC_TRANSPARENT": "Transparent",
    "KC_TRNS": "Transparent",
    "KC_NO": "Disabled",
    "KC_ESCAPE": "Esc",
    "KC_BSPC": "Backspace",
    "KC_ENTER": "Enter",
    "KC_SPACE": "Space",
    "KC_TAB": "Tab",
    "KC_TILD": "~",
    "KC_MINUS": "-",
    "KC_EQUAL": "=",
    "KC_QUOTE": "'",
    "KC_SCLN": ";",
    "KC_COMMA": ",",
    "KC_DOT": ".",
    "KC_EXLM": "!",
    "KC_AT": "@",
    "KC_HASH": "#",
    "KC_DLR": "$",
    "KC_PERC": "%",
    "KC_CIRC": "^",
    "KC_AMPR": "&",
    "KC_ASTR": "*",
    "KC_LPRN": "(",
    "KC_RPRN": ")",
    "KC_LCBR": "{",
    "KC_RCBR": "}",
    "KC_LBRC": "[",
    "KC_RBRC": "]",
    "KC_PIPE": "|",
    "KC_GRAVE": "`",
    "KC_BSLS": "\\",
    "KC_UNDS": "_",
    "KC_PLUS": "+",
    "KC_LEFT": "←",
    "KC_RIGHT": "→",
    "KC_UP": "↑",
    "KC_DOWN": "↓",
    "KC_LEFT_CTRL": "Ctrl",
    "KC_RIGHT_CTRL": "Ctrl",
    "KC_LEFT_SHIFT": "Shift",
    "KC_RIGHT_SHIFT": "Shift",
    "KC_LEFT_ALT": "Option",
    "KC_RIGHT_ALT": "Option",
    "KC_LEFT_GUI": "Cmd",
    "KC_RIGHT_GUI": "Cmd",
    "KC_PAGE_UP": "Page Up",
    "KC_PGDN": "Page Down",
    "KC_AUDIO_VOL_UP": "Volume +",
    "KC_MS_UP": "Mouse ↑",
    "KC_MS_DOWN": "Mouse ↓",
    "KC_MS_LEFT": "Mouse ←",
    "KC_MS_RIGHT": "Mouse →",
    "KC_MS_WH_UP": "Wheel ↑",
    "KC_MS_WH_DOWN": "Wheel ↓",
    "KC_MS_WH_LEFT": "Wheel ←",
    "KC_MS_WH_RIGHT": "Wheel →",
    "KC_MS_BTN1": "Mouse 1",
    "KC_MS_BTN2": "Mouse 2",
    "CW_TOGG": "Caps Word toggle",
    "RGB_TOG": "RGB on/off",
    "RGB_MODE_FORWARD": "Next RGB effect",
    "RGB_VAD": "Dim RGB",
    "RGB_VAI": "Brighten RGB",
    "MOON_LED_LEVEL": "LED brightness",
    "ST_MACRO_0": "Delete word",
    "MACRO_MARKDOWN_LINK": "Markdown link",
    "MACRO_REOPEN_TAB": "Reopen tab",
    "MACRO_DELETE_LINE": "Delete to line start",
    "DUAL_FUNC_0": "# / Shift",
    "DUAL_FUNC_1": "% / Cmd",
    "TD(DANCE_0)": "Volume − / mute",
}

MODIFIERS = {
    "MOD_LCTL": "Ctrl",
    "MOD_RCTL": "Ctrl",
    "MOD_LSFT": "Shift",
    "MOD_RSFT": "Shift",
    "MOD_LALT": "Option",
    "MOD_RALT": "Option",
    "MOD_LGUI": "Cmd",
    "MOD_RGUI": "Cmd",
    "LCTL": "Ctrl",
    "RCTL": "Ctrl",
    "LSFT": "Shift",
    "RSFT": "Shift",
    "LALT": "Option",
    "RALT": "Option",
    "LGUI": "Cmd",
    "RGUI": "Cmd",
}


def split_arguments(text: str) -> list[str]:
    """Split a C macro argument list while preserving nested expressions."""
    result: list[str] = []
    start = 0
    depth = 0
    in_string = False
    escaped = False

    for index, char in enumerate(text):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            result.append(text[start:index].strip())
            start = index + 1

    final = text[start:].strip()
    if final:
        result.append(final)
    return result


def parse_layouts(source: str, source_name: str) -> dict[int, list[str]]:
    """Extract each layer's top-level LAYOUT_moonlander arguments."""
    layouts: dict[int, list[str]] = {}
    pattern = re.compile(r"\[(\d+)\]\s*=\s*LAYOUT_moonlander\s*\(")

    for match in pattern.finditer(source):
        layer = int(match.group(1))
        start = match.end()
        depth = 1
        in_string = False
        escaped = False
        index = start

        while index < len(source) and depth:
            char = source[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            index += 1

        if depth:
            raise ValueError(f"Unclosed LAYOUT_moonlander call in {source_name}")

        arguments = split_arguments(source[start : index - 1])
        if len(arguments) != 72:
            raise ValueError(
                f"Layer {layer} in {source_name} has {len(arguments)} keys; expected 72"
            )
        layouts[layer] = arguments

    if not layouts:
        raise ValueError(f"No Moonlander layouts found in {source_name}")
    return layouts


def key_label(token: str) -> str:
    token = token.strip()
    if token in SPECIAL_KEYS:
        return SPECIAL_KEYS[token]

    layer_action = re.fullmatch(r"(MO|TT|TG)\((\d+)\)", token)
    if layer_action:
        action, layer = layer_action.groups()
        name = LAYER_NAMES.get(int(layer), f"Layer {layer}")
        if action == "MO":
            return f"Hold: {name}"
        if action == "TG":
            return f"Toggle: {name}"
        return f"Hold/tap-toggle: {name}"

    tap_hold = re.fullmatch(r"MT\((.*)\)", token)
    if tap_hold:
        arguments = split_arguments(tap_hold.group(1))
        if len(arguments) == 2:
            modifier = MODIFIERS.get(arguments[0], arguments[0])
            return f"{key_label(arguments[1])} / {modifier}"

    modified_key = re.fullmatch(r"(LCTL|RCTL|LSFT|RSFT|LALT|RALT|LGUI|RGUI)\((.*)\)", token)
    if modified_key:
        modifier, key = modified_key.groups()
        return f"{MODIFIERS[modifier]}+{key_label(key)}"

    if token.startswith("KC_"):
        name = token[3:]
        if len(name) == 1:
            return name
        if name.startswith("F") and name[1:].isdigit():
            return name
        return name.replace("_", " ").title()
    return token


def layer_colors(colors: list[str]) -> str:
    visible = sorted({color for color in colors if color not in {"OFF", "ANIM"}})
    notes = [color.title() for color in visible]
    if "ANIM" in colors:
        notes.append("animated RGB effect")
    return ", ".join(notes) if notes else "No LEDs lit"


def render_layer(layer: int, keys: list[str], colors: list[str] | None) -> list[str]:
    name = LAYER_NAMES.get(layer, f"Layer {layer}")
    lines = [f"### Layer {layer}: {name}", ""]
    if colors is not None:
        lines.extend([f"**Lighting:** {layer_colors(colors)}", ""])

    lines.extend(
        [
            "| Physical row | Left half | Right half |",
            "| --- | --- | --- |",
        ]
    )
    offset = 0
    for row_name, width, half_width in LAYOUT_ROWS:
        row = keys[offset : offset + width]
        left = " · ".join(key_label(key).replace("|", "\\|") for key in row[:half_width])
        right = " · ".join(key_label(key).replace("|", "\\|") for key in row[half_width:])
        lines.append(f"| {row_name} | {left} | {right} |")
        offset += width
    lines.append("")
    return lines


def generate() -> str:
    keymaps = parse_layouts(KEYMAP.read_text(), str(KEYMAP.relative_to(HERE)))
    color_source = COLOURS.read_text()
    color_layouts = parse_layouts(color_source, str(COLOURS.relative_to(HERE)))

    lines = [
        "# Moonlander keymap",
        "",
        "> Generated from `keymap/keymap.c` and `keymap/colours.h` by `generate-readme.py`.",
        "> Run `nix shell nixpkgs#python3 --command python3 keyboards/moonlander/generate-readme.py` from the repository root after changing the keymap.",
        "",
        "The key names are shown left-to-right for each hand. `Transparent` means the key falls through to a lower active layer.",
        "For tap/hold keys, the first action is on tap and the second is on hold.",
        "",
    ]

    for layer in sorted(keymaps):
        lines.extend(render_layer(layer, keymaps[layer], color_layouts.get(layer)))

    lines.extend(
        [
            "## Custom actions",
            "",
            "| Key label | Action |",
            "| --- | --- |",
            "| Delete word | Option+Backspace |",
            "| Markdown link | Types `[]()` and leaves the cursor between the brackets |",
            "| Reopen tab | Cmd+Shift+T |",
            "| Delete to line start | Cmd+Backspace |",
            "| Volume − / mute | Tap for volume down; double-tap for mute |",
            "| `# / Shift` | Tap for `#`; hold for Shift |",
            "| `% / Cmd` | Tap for `%`; hold for Cmd |",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the checked-in README differs from the generated output",
    )
    args = parser.parse_args()

    try:
        generated = generate()
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    if args.check:
        if not README.exists() or README.read_text() != generated:
            print(f"{README.relative_to(HERE)} is out of date; run {Path(__file__).name}", file=sys.stderr)
            return 1
        return 0

    README.write_text(generated)
    print(f"Updated {README.relative_to(HERE)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
