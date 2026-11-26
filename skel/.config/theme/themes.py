#!/usr/bin/env python3
"""Switch the whole desktop to an Axyl design or an opencode colour theme.

Designs are defined in ~/.config/theme/designs.json and set the palette *and*
the layout (bar style/position, rounding, gaps, blur). opencode themes are
vendored into ~/.config/theme/opencode-themes/ by `sync`; their dark variant is
mapped onto the palette schema and keeps the current layout. Either way
~/.config/theme/render.py regenerates every app:

    Hyprland + hyprlock   ~/.config/hypr/conf/{palette,design}.lua, hyprlock.conf
    waybar                ~/.config/waybar/{config,style.css}
    kitty                 ~/.config/kitty/colors.conf
    rofi / starship / nvim / cava
    KDE / Qt / GTK        kdeglobals, color-schemes/opencode.colors,
                          qt6ct/colors/opencode.conf, gtk-3.0, gtk-4.0

The opencode TUI itself is switched through ~/.config/opencode/cli.json
(`theme.name` + `theme.mode = "dark"`) followed by `opencode reload`.

Usage
    themes.py list              list designs and themes (current marked)
    themes.py current           print the active design/theme name
    themes.py set <name>        switch to <name> (design or opencode theme)
    themes.py pick              rofi picker (used by SUPER+SHIFT+T)
    themes.py sync              re-vendor themes for the installed opencode

Notes
    * The KDE scheme id stays "opencode" on purpose: Dolphin and other KF6
      apps point at it through kdeglobals [UiSettings] ColorScheme.
    * Only dark variants are used; the whole desktop is dark-first.
    * "lucent-orng" is excluded: every background in it is transparent.
    * Entries in ~/.config/theme/designs.json are Axyl designs: they set the
      palette *and* the layout (bar style/position, rounding, gaps, blur), and
      map to an opencode theme for the TUI. Switching to an opencode theme
      keeps the current layout.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

CONFIG = Path.home() / ".config"
THEME_DIR = CONFIG / "theme"
THEMES = THEME_DIR / "opencode-themes"
PALETTE = THEME_DIR / "palette.json"
DESIGNS = THEME_DIR / "designs.json"
PREV = THEME_DIR / "palette.prev.json"
RENDER = THEME_DIR / "render.py"
CLI_JSON = CONFIG / "opencode" / "cli.json"
ROFI_STYLE = CONFIG / "rofi" / "style.rasi"

# Themes whose backgrounds are transparent -- unusable for opaque GUI theming.
SKIP = {"lucent-orng"}

GITHUB_TREE = "https://api.github.com/repos/anomalyco/opencode/git/trees/{ref}?recursive=1"
GITHUB_RAW = "https://raw.githubusercontent.com/anomalyco/opencode/{ref}/{path}"
ASSET_PREFIX = "packages/tui/src/theme/assets/"


# ------------------------------------------------------------------ colour ---
def norm_hex(value) -> str | None:
    """Normalise #rgb/#rgba/#rrggbb/#rrggbbaa to lowercase #rrggbb."""
    if not isinstance(value, str) or not value.startswith("#"):
        return None
    h = value[1:].strip()
    if len(h) in (3, 4):
        h = "".join(c * 2 for c in h[:3])
    elif len(h) == 8:
        h = h[:6]
    if len(h) != 6:
        return None
    try:
        int(h, 16)
    except ValueError:
        return None
    return "#" + h.lower()


def rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(r: float, g: float, b: float) -> str:
    clamp = lambda x: max(0, min(255, round(x)))
    return "#%02x%02x%02x" % (clamp(r), clamp(g), clamp(b))


def mix(a: str, b: str, t: float) -> str:
    """Blend a -> b; t=0 returns a, t=1 returns b."""
    ar, ag, ab = rgb(a)
    br, bg, bb = rgb(b)
    return to_hex(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)


def tint(value: str, t: float) -> str:
    return mix(value, "#ffffff", t)


def luminance(value: str) -> float:
    def channel(c: int) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = rgb(value)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# ------------------------------------------------------------------ themes ---
def designs() -> dict:
    try:
        return json.loads(DESIGNS.read_text())
    except (OSError, ValueError):
        return {}


def design_names() -> list[str]:
    return [k for k in designs() if not k.startswith("_")]


def theme_names() -> list[str]:
    return sorted(
        p.stem for p in THEMES.glob("*.json") if p.is_file() and p.stem not in SKIP
    )


def load_theme(name: str) -> dict:
    path = THEMES / f"{name}.json"
    if not path.is_file():
        raise SystemExit(f"unknown theme: {name}\nRun: {sys.argv[0]} list")
    return json.loads(path.read_text())


def resolve(doc: dict, token: str, mode: str = "dark"):
    """Resolve a v1 theme token through `defs` for one mode."""
    value = doc.get("theme", {}).get(token)
    if value is None:
        return None
    if isinstance(value, dict):
        value = value.get(mode)
    seen: set[str] = set()
    defs = doc.get("defs", {})
    while isinstance(value, str) and value in defs:
        if value in seen:
            break
        seen.add(value)
        value = defs[value]
    return value


def build_palette(name: str) -> dict:
    doc = load_theme(name)

    def pick(token: str, fallback: str) -> str:
        token_value = resolve(doc, token)
        return norm_hex(token_value) or fallback

    # Seed a couple of values that everything else can fall back to.
    fg_seed = pick("text", "#eeeeee")
    bg = pick("background", "") or pick("backgroundPanel", "") or "#0a0a0a"

    fg = pick("text", fg_seed)
    fg_muted = pick("textMuted", mix(fg, bg, 0.5))
    bg_panel = pick("backgroundPanel", mix(bg, fg, 0.06))
    bg_elem = pick("backgroundElement", mix(bg, fg, 0.10))
    border = pick("border", mix(bg, fg, 0.25))
    # A gray ramp rather than borderActive: some themes use a near-white
    # borderActive (gruvbox), which makes a scrollbar/track glaring.
    scrollbar = mix(bg, fg, 0.35)
    accent = pick("primary", pick("secondary", fg))
    secondary = pick("secondary", accent)
    accent_alt = pick("accent", accent)
    red = pick("error", "#e06c75")
    green = pick("success", "#7fd88f")
    orange = pick("warning", "#f5a742")
    cyan = pick("info", "#56b6c2")
    yellow = tint(orange, 0.30)

    return {
        "_comment": (
            f"opencode theme '{name}' (dark variant), vendored from opencode and "
            "mapped by ~/.config/theme/themes.py. Source of truth for render.py"
        ),
        "name": name,
        "bg": bg,
        "bg_panel": bg_panel,
        "bg_elem": bg_elem,
        "overlay": mix(bg, fg, 0.30),
        "border": border,
        "scrollbar": scrollbar,
        "fg": fg,
        "fg_muted": fg_muted,
        "accent": accent,
        "secondary": secondary,
        "accent_alt": accent_alt,
        "red": red,
        "green": green,
        "yellow": yellow,
        "orange": orange,
        "cyan": cyan,
        "bright": {
            "red": tint(red, 0.30),
            "green": tint(green, 0.30),
            "yellow": tint(yellow, 0.30),
            "blue": tint(secondary, 0.30),
            "purple": tint(accent_alt, 0.30),
            "cyan": tint(cyan, 0.30),
            "white": "#ffffff",
            "black": mix(bg, fg, 0.30),
        },
    }


# ------------------------------------------------------------------ actions ---
def existing_layout() -> dict:
    try:
        return json.loads(PALETTE.read_text()).get("layout") or {}
    except (OSError, ValueError):
        return {}


def current_name() -> str:
    try:
        name = json.loads(PALETTE.read_text()).get("name")
        if name:
            return str(name)
    except (OSError, ValueError):
        pass
    try:
        name = json.loads(CLI_JSON.read_text()).get("theme", {}).get("name")
        if name:
            return str(name)
    except (OSError, ValueError, AttributeError):
        pass
    return "opencode"


def render() -> None:
    subprocess.run([sys.executable, str(RENDER), "--reload"], check=True)


def set_tui_theme(name: str) -> None:
    try:
        config = json.loads(CLI_JSON.read_text())
    except (OSError, ValueError):
        config = {"$schema": "https://opencode.ai/v2/cli.json"}
    config["theme"] = {"name": name, "mode": "dark"}
    CLI_JSON.parent.mkdir(parents=True, exist_ok=True)
    CLI_JSON.write_text(json.dumps(config, indent=2) + "\n")
    if shutil.which("opencode"):
        try:
            subprocess.run(
                ["opencode", "reload"], capture_output=True, timeout=20, check=False
            )
        except (subprocess.TimeoutExpired, OSError):
            pass


def notify(message: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(
            ["notify-send", "-a", "Theme", "-t", "2500", message], check=False
        )
    else:
        print(message)


def cmd_list() -> int:
    rows = [(n, "design") for n in design_names()]
    rows += [(n, "theme") for n in theme_names()]
    if not rows:
        print("no designs or themes -- run: %s sync" % sys.argv[0])
        return 1
    current = current_name()
    width = max(len(n) for n, _ in rows)
    for name, kind in rows:
        mark = "\u25cf" if name == current else " "
        print(f"{mark} {name:<{width}}  {kind}")
    return 0


def cmd_current() -> int:
    print(current_name())
    return 0


def cmd_set(name: str) -> int:
    presets = designs()
    if name in presets:
        preset = presets[name]
        palette = {
            "_comment": (
                f"Axyl design '{name}' -- defined in ~/.config/theme/designs.json, "
                "rendered by ~/.config/theme/render.py"
            ),
            "name": name,
        }
        palette.update(preset["palette"])
        palette["layout"] = preset.get("layout", {})
        tui = preset.get("tui", "opencode")
    elif name in theme_names():
        palette = build_palette(name)
        palette["layout"] = existing_layout()
        tui = name
    else:
        print(f"unknown design or theme: {name}", file=sys.stderr)
        print("run: %s list" % sys.argv[0], file=sys.stderr)
        return 2

    ratio = contrast(palette["fg"], palette["bg"])
    if ratio < 4.5:
        print(
            f"warning: {name} has low text contrast ({ratio:.2f}:1)", file=sys.stderr
        )

    old = PALETTE.read_text() if PALETTE.exists() else None
    if old is not None:
        PREV.write_text(old)

    PALETTE.write_text(json.dumps(palette, indent=2) + "\n")
    try:
        render()
    except subprocess.CalledProcessError:
        if old is not None:
            PALETTE.write_text(old)
        raise SystemExit("render.py failed -- previous palette restored")

    set_tui_theme(tui)
    notify(f"Theme: {name}")
    print(f"theme -> {name}")
    return 0


def cmd_pick() -> int:
    names = design_names() + theme_names()
    if not names:
        notify("No designs or themes -- run themes.py sync")
        return 1
    if not shutil.which("rofi"):
        print("rofi not found", file=sys.stderr)
        return 1

    current = current_name()
    lines = [("\u25cf " if n == current else "  ") + n for n in names]
    command = ["rofi", "-dmenu", "-i", "-no-custom", "-p", "Theme"]
    if ROFI_STYLE.is_file():
        command += ["-theme", str(ROFI_STYLE)]

    result = subprocess.run(
        command, input="\n".join(lines) + "\n", capture_output=True, text=True
    )
    if result.returncode != 0:
        return 0
    choice = result.stdout.strip()
    if choice.startswith("\u25cf "):
        choice = choice[2:].strip()
    if not choice:
        return 0
    return cmd_set(choice)


def installed_version() -> str:
    try:
        out = subprocess.run(
            ["opencode", "--version"], capture_output=True, text=True, timeout=10
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        out = ""
    for token in out.replace("v", " ").split():
        parts = token.split(".")
        if len(parts) == 3 and all(p.isdigit() for p in parts):
            return token
    raise SystemExit("could not detect the installed opencode version")


def fetch(url: str, binary: bool = False):
    request = urllib.request.Request(url, headers={"User-Agent": "opencode-theme-sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read()
    return data if binary else json.loads(data)


def cmd_sync() -> int:
    version = installed_version()
    ref = f"v{version}"
    print(f"syncing themes from opencode {ref} ...")
    tree = fetch(GITHUB_TREE.format(ref=ref))
    paths = [
        entry["path"]
        for entry in tree.get("tree", [])
        if entry["path"].startswith(ASSET_PREFIX)
        and entry["path"].endswith(".json")
        and "/v2/" not in entry["path"]
    ]
    if not paths:
        raise SystemExit("no theme assets found for " + ref)

    THEMES.mkdir(parents=True, exist_ok=True)
    written = set()
    for path in paths:
        name = Path(path).stem
        target = THEMES / f"{name}.json"
        target.write_bytes(fetch(GITHUB_RAW.format(ref=ref, path=path), binary=True))
        written.add(target.name)
        print(f"  {name}")

    for stale in THEMES.glob("*.json"):
        if stale.name not in written:
            stale.unlink()
            print(f"  removed {stale.name}")

    (THEMES / ".source").write_text(
        f"opencode {version}\n{ref}\n{GITHUB_TREE.format(ref=ref)}\n"
        f"synced {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
    )
    print(f"{len(written)} themes in {THEMES}")
    return 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0
    command = args[0]
    if command == "list":
        return cmd_list()
    if command == "current":
        return cmd_current()
    if command == "set":
        if len(args) < 2:
            print("usage: themes.py set <name>", file=sys.stderr)
            return 2
        return cmd_set(args[1])
    if command == "pick":
        return cmd_pick()
    if command == "sync":
        return cmd_sync()
    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
