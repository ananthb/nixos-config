#!/usr/bin/env python3
"""Merge Nix-managed OpenLogi settings into the live config."""

from __future__ import annotations

import os
import sys
import tempfile
from collections.abc import MutableMapping
from pathlib import Path

import tomlkit


def merge(target: MutableMapping, overlay: MutableMapping) -> None:
    for key, value in overlay.items():
        current = target.get(key)
        if isinstance(current, MutableMapping) and isinstance(value, MutableMapping):
            merge(current, value)
        else:
            target[key] = value


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} OVERLAY SEED TARGET", file=sys.stderr)
        return 2

    overlay_path, seed_path, target_path = map(Path, sys.argv[1:])
    overlay = tomlkit.parse(overlay_path.read_text())

    if target_path.exists():
        original = target_path.read_text()
        config = tomlkit.parse(original)
    else:
        original = None
        config = tomlkit.parse(seed_path.read_text())

    merge(config, overlay)
    rendered = tomlkit.dumps(config)
    if original == rendered:
        return 0

    target_path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(
        prefix=f".{target_path.name}.", dir=target_path.parent
    )
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as temp:
            temp.write(rendered)
            temp.flush()
            os.fsync(temp.fileno())
        os.replace(temp_name, target_path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
