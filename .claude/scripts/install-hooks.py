#!/usr/bin/env python3
"""Update ~/.claude/settings.json hook commands to point to the installed ClaudeTerminalHelper.

Usage: install-hooks.py <path-to-ClaudeTerminalHelper>

Idempotent — safe to run multiple times.
"""

import json
import os
import sys
import tempfile

SETTINGS_PATH = os.path.expanduser("~/.claude/settings.json")


def update_hooks(settings: dict, new_binary: str) -> tuple[dict, int]:
    """Replace ClaudeTerminalHelper references in all hook commands.
    Returns updated settings and count of replacements."""
    count = 0
    hooks = settings.get("hooks", {})
    for event_name, hook_list in hooks.items():
        if not isinstance(hook_list, list):
            continue
        for hook in hook_list:
            if not isinstance(hook, dict):
                continue
            cmd = hook.get("command", "")
            if "ClaudeTerminalHelper" in cmd:
                # Replace everything up to and including the binary name
                parts = cmd.split("ClaudeTerminalHelper", 1)
                hook["command"] = new_binary + parts[1]
                count += 1
    settings["hooks"] = hooks
    return settings, count


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path-to-ClaudeTerminalHelper>", file=sys.stderr)
        sys.exit(1)

    new_binary = sys.argv[1]
    if not os.path.isfile(new_binary):
        print(f"Error: binary not found at {new_binary}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(SETTINGS_PATH):
        print(f"Error: settings file not found at {SETTINGS_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
        settings = json.load(f)

    settings, count = update_hooks(settings, new_binary)

    if count == 0:
        print("No ClaudeTerminalHelper hook commands found — nothing to update.")
        return

    # Atomic write: write to temp file in same directory, then rename
    dir_path = os.path.dirname(SETTINGS_PATH)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".json.tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2)
            f.write("\n")
        os.replace(tmp_path, SETTINGS_PATH)
    except Exception:
        os.unlink(tmp_path)
        raise

    print(f"Updated {count} hook command(s) to use: {new_binary}")


if __name__ == "__main__":
    main()
