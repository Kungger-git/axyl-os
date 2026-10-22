#!/usr/bin/env bash
# ~/.config/rofi/keybinds.sh
# Rofi cheat sheet for the live Hyprland keybinds (reads `hyprctl binds -j`).
# Bound to SUPER + / in conf/keybinds.lua.

set -euo pipefail

entries="$(hyprctl binds -j | python3 -c '
import json, sys

MODS = [(1, "SHIFT"), (2, "CAPS"), (4, "CTRL"), (8, "ALT"),
        (16, "MOD2"), (32, "MOD3"), (64, "SUPER"), (128, "MOD5")]

binds = json.load(sys.stdin)
rows = []
for b in binds:
    if b.get("catch_all"):
        continue
    desc = (b.get("description") or "").strip()
    if not desc:
        continue
    mods = " + ".join(name for bit, name in MODS if b.get("modmask", 0) & bit)
    key = b.get("key") or ""
    combo = f"{mods} + {key}".strip(" +") if (mods or key) else "?"
    if b.get("mouse"):
        combo += " (mouse)"
    sub = b.get("submap") or "default"
    rows.append((sub, combo, desc))

rows.sort(key=lambda r: (r[0] != "default", r[0], r[1].lower()))

for sub, combo, desc in rows:
    label = combo if sub == "default" else f"[{sub}] {combo}"
    print(f"{label:<34} {desc}")
')"

if [ -z "$entries" ]; then
  echo "No described keybinds found."
  exit 0
fi

printf '%s\n' "$entries" \
  | rofi -dmenu -i -no-custom -p "Keybinds" -theme ~/.config/rofi/style.rasi
