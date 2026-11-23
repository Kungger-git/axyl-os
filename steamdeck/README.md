# Axyl Deck — Hyprland on stock SteamOS

`steamdeck/` ships a desktop application and a session that add an **Axyl
Hyprland desktop** to a stock SteamOS Steam Deck, without replacing Game Mode or
KDE. It installs the Hyprland stack as SteamOS system packages, registers an
SDDM session, and switches to it one-shot, so a reboot always returns to Game
Mode.

This is the `steam-deck` branch only. `master` does not use this directory.

**Visual guide:** [CONTROLS.md](CONTROLS.md) shows what every app button, Waybar
pill and physical control does, with diagrams.

---

## What it does

- Installs `hyprland`, `waybar`, `foot`, `rofi`, `mako`, `hyprlock`, `hypridle`,
  portals, Deck input/OSK helpers and fonts from the **SteamOS repositories**
  with `pacman -S --needed` (never `-Syu`, never a downgrade).
- Adds the `axyl-hyprland.desktop` Wayland session and symlinks the commands into
  `/usr/local/bin`.
- Copies the shared `skel/` desktop config, then overlays the Deck profile from
  `steamdeck/config/`: 1280x800 landscape monitor, touchpad/gesture tuning,
  compact Waybar, and 1280x800 Foot/Rofi profiles.
- Registers **Axyl Deck**, a GTK3 app (also on the desktop and in Rofi) that
  switches sessions, opens Steam Big Picture, opens a terminal, toggles the
  on-screen keyboard, and exposes the Deck hardware controls.
- Renders the opencode palette in **`hypr` scope**, so KDE, Qt6ct, GTK and the
  KDE colour scheme are never restyled.
- Stages a self-contained repair tree at `~/.local/state/axyl-deck/tree/` so the
  app can re-apply the setup after a SteamOS update.

Nothing in `/etc` is modified and `DefaultLoginMode` is never changed.

---

## Requirements

- SteamOS 3.9.x on a Steam Deck (LCD or OLED), booted into **Desktop Mode**.
- An internet connection (packages come from the SteamOS repos).
- At least ~600 MB free on `/` (the installer aborts below 350 MB).
- The `deck` user's password, for `sudo`.

Hyprland 0.56 on SteamOS reads the Lua config (`~/.config/hypr/hyprland.lua`);
editing `.conf` files has no effect.

---

## Install

From the repository root, on the Deck:

```bash
cd steamdeck
./install.sh
```

The installer asks for confirmation, then runs the package step through `sudo`.
Useful flags:

| Flag | Effect |
|---|---|
| `--yes` | no confirmation prompts |
| `--repair` | re-apply packages, files and the session entry (keeps backups) |
| `--user-only` | write only the user configuration |
| `--no-packages` | skip pacman |
| `--user NAME` | target user (required when run as root/`pkexec`) |

When it finishes it prints the next command. If SteamOS does not yet list the
session, restart SDDM once (`sudo systemctl restart sddm`) or reboot.

Every overwritten user file is backed up to
`~/.local/state/axyl-deck/backup-<UTC>/`, and the pre-install package set is
saved to `packages-before.txt`.

---

## Switch to Hyprland

```bash
axyl-switch hyprland        # one-shot switch to the Axyl Hyprland session
```

or open **Axyl Deck** and press **Switch to Axyl Hyprland**. The switch is
one-shot: `DefaultLoginMode` stays `game`, so a reboot (or a crash) comes back to
Game Mode.

On first login the session renders the palette, starts Waybar, Mako, the
clipboard watcher, the polkit agent and **Steam in silent mode** (Steam Input
gives the Deck buttons and trackpads their mapping).

---

## Return to Game Mode

The primary way out is the **Return to Game Mode** button in the Axyl Deck app
(or `SUPER + SHIFT + Escape`). It closes Steam and switches back through
`steamosctl`; if SDDM does not pick the change up, the app ends the desktop
session so SDDM re-reads its config.

```bash
axyl-switch game --yes
```

Rebooting also returns to Game Mode.

---

## The Axyl Deck app and CLI

`axyl-switch` is both the GUI and the CLI.

```bash
axyl-switch                 # open the app
axyl-switch hyprland        # one-shot switch to Hyprland
axyl-switch kde             # one-shot switch to KDE Plasma
axyl-switch game            # return to Steam Game Mode
axyl-switch steam           # open Steam Big Picture
axyl-switch terminal        # open foot
axyl-switch keyboard        # toggle the on-screen keyboard
axyl-switch controls        # open the Deck hardware controls
axyl-switch status          # session + readiness information
axyl-switch logs            # last log lines
axyl-switch setup           # repair (re-run the installer via pkexec)
```

The app shows the current session, readiness (session entry, Hyprland binary,
TDP, governor, battery) and the action buttons. It is a floating 760x680 dialog,
not a tiled window.

---

## Deck controls

See [CONTROLS.md](CONTROLS.md) for a diagram of every physical control and app
button.

| Control | Result |
|---|---|
| Trackpads / touchscreen | Pointer and tapping; the touchscreen is rotated to match the panel (`touchdevice.transform = 3`) |
| Touchpad | Tap-to-click, natural scroll, clickfinger |
| Four-finger horizontal swipe | Previous / next workspace |
| `SUPER + Return` | Foot terminal |
| `SUPER + D` | Rofi launcher |
| `SUPER + A` | Rofi window switcher |
| `SUPER + W` / `SUPER + SHIFT + W` | Steam Big Picture |
| `SUPER + E` | Dolphin |
| `SUPER + SHIFT + K` / `SUPER + CTRL + K` | On-screen keyboard |
| `SUPER + SHIFT + Escape` | Return to Steam Game Mode |
| `SUPER + SHIFT + Q` | Power menu |
| `SUPER + /` | Keybind cheat sheet |

The remaining binds are the shared Axyl set from
`skel/.config/hypr/conf/keybinds.lua`. The Deck profile removes the stock
`SUPER + W` browser bind (Brave may be absent) and the stock `SUPER + L` lock
bind (see below).

**Steam Input** must be enabled in Steam so the Deck's physical buttons and
trackpads produce input. Steam runs silently in the background; open Big Picture
with `SUPER + W` when you want the gamepad UI.

### On-screen keyboard

`squeekboard` only raises itself for a client that announces `text-input-v3`, and
Rofi never does, so `axyl-osk` toggles it through its D-Bus API
(`sm.puri.OSK0` / `SetVisible`). It also starts the keyboard and recovers the
session bus from the compositor when invoked outside the session.

The SteamOS `squeekboard` package ships the binary without layout data, so the
installer copies a vendored `us.yaml` to
`~/.local/share/squeekboard/keyboards/us.yaml`. Without it the keyboard is blank.

The `KB` pill in Waybar taps through to `axyl-osk toggle`. Touch input is rotated
to match the panel, so taps land where you put your finger; the same transform
also makes every other on-screen target reachable with the touchscreen.

### Lock screen is disabled

`hyprlock` is a fullscreen window and `squeekboard` is a layer surface, so the
on-screen keyboard cannot be drawn above the lock screen. On a Deck with no
hardware keyboard that would be a lockout. `SUPER + L` therefore shows a
notification instead of locking. Sleep with the power button, or attach a
keyboard and run `hyprlock` manually if you want to lock.

---

## Hardware controls

`axyl-deck` wraps Valve's `steamosctl`, `brightnessctl` and `wpctl`:

```bash
axyl-deck status            # battery, brightness, volume, TDP, governor, fan
axyl-deck tdp 10            # TDP limit in watts (3-15 W on the LCD Deck)
axyl-deck profile max       # eco | balanced | max (TDP + governor + fan)
axyl-deck brightness up
axyl-deck volume mute
axyl-deck governor performance
axyl-deck fan bios
axyl-deck files             # open Dolphin
axyl-deck screenshot region
```

On the LCD Deck only TDP, CPU governor and fan control are exposed through
`steamosctl`; the performance/GPU profile interfaces are unavailable.

---

## Updates, space and rollback

- **SteamOS updates** rewrite `/usr` and the SDDM session list. Re-run
  `./install.sh --repair` (or **Repair** in the app, which uses `pkexec`) to put
  the session entry and `/usr/local/bin` symlinks back. User configuration under
  `~/.config` is untouched by updates.
- **pacman cache:** packages are downloaded to `~/.cache/axyl-pacman` and removed
  after the transaction, because `/` is small. The SteamOS database lives in
  `/usr/lib/holo/pacmandb`; the installer never syncs or upgrades.
- **Uninstall** (packages are kept, since other sessions may use them):

  ```bash
  cd steamdeck
  ./uninstall.sh              # remove session entry, commands, app icon
  ./uninstall.sh --purge      # also remove the user config
  ```

  Backups under `~/.local/state/axyl-deck/backup-*` are never deleted.

---

## Files

```
steamdeck/
  install.sh                          package + session + user install
  uninstall.sh                        reversible removal
  bin/axyl-switch                     GTK3 app and session-switch CLI
  bin/axyl-hyprland-session           SDDM session wrapper and environment
  bin/axyl-deck                       TDP/governor/fan/brightness/volume CLI
  bin/axyl-osk                        squeekboard/wvkbd toggle
  config/hypr/conf/device.lua         Deck monitor, input, binds, Steam autostart
  config/waybar/config                compact 1280x800 bar
  config/rofi/config.rasi             touch-friendly launcher
  config/foot/foot.ini                compact terminal
  system/wayland-sessions/axyl-hyprland.desktop
  system/applications/axyl-switch.desktop
  system/axyl-deck.svg
  share/squeekboard/us.yaml           vendored layout for squeekboard
```

Runtime state lives in `~/.local/state/axyl-deck/`:

| File | Purpose |
|---|---|
| `switch.log` | every switch and `steamosctl` call |
| `session.log` | Hyprland session output |
| `keyboard.log` | on-screen keyboard events |
| `packages-before.txt` | package set at install time |
| `tree/` | staged copy used by **Repair** |
| `backup-*` | timestamped user-file backups |
