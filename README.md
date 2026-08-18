# Axyl Linux

Axyl is a custom Linux live/install ISO built with `archiso`. It boots directly into a fully configured **bspwm** desktop themed with the Claude color scheme — dark navy backgrounds (`#1a1a2e`) and warm coral accents (`#d97757`). On first boot a terminal opens automatically, guiding the user through installation. Everything from the window manager to the editor to the shell prompt is pre-configured and ready to use.

Two variants are available:

| Variant | Init system | UEFI bootloader |
|---|---|---|
| `arch` | systemd | systemd-boot |
| `artix` | runit | GRUB |

Both build inside Docker — no native Arch or Artix host required.

---

## First-Time Setup

Run once on the build machine to install Docker and optionally QEMU:

```bash
chmod +x setup.sh
sudo ./setup.sh
```

Installs: `docker`, `docker-buildx` (eliminates legacy builder warning). Optionally installs `qemu-system-x86` + `edk2-ovmf` for ISO testing.

---

## How to Build

```bash
# Arch variant (systemd)
./build.sh arch

# Artix variant (runit)
./build.sh artix
```

The script rebuilds the Docker builder image from scratch on every run, then runs `mkarchiso` inside the container. The finished ISO is written to `./axyl-out/`.

### Flash to USB

```bash
sudo bash flash.sh ./axyl-out/axyl-*.iso /dev/sdX
```

### Test in QEMU

```bash
# BIOS
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G -boot d

# UEFI (requires edk2-ovmf)
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

---

## Key Features

- **Window manager**: bspwm with 9 workspaces, 2px borders, 8px gaps
- **Color scheme**: Claude palette — `#1a1a2e` background, `#d97757` accent, `#e6e1d8` foreground
- **Login**: greetd with X11 autologin as `axyl`
- **Bar**: polybar — workspaces, window title, CPU, memory, volume, network, clock
- **App launcher**: rofi (drun/run/window modes)
- **Terminal**: kitty with JetBrains Mono 12pt and full Claude 16-color palette
- **Shell**: zsh + Oh My Zsh (zsh-autosuggestions, zsh-syntax-highlighting)
- **Browser**: qutebrowser
- **Editor**: neovim with custom Claude color scheme (pure Lua, no plugins)
- **File manager**: lf (TUI; opens nsxiv/zathura/mpv via mime)
- **PDF viewer**: zathura with mupdf backend, themed to Claude palette
- **Image viewer**: nsxiv
- **Media**: mpv + ffmpeg + playerctl (media key support)
- **Audio**: PipeWire (PulseAudio-compatible) with pamixer (hotkeys + OSD) and pavucontrol
- **Bluetooth**: bluez + blueman (systray applet)
- **Compositor**: picom (xrender backend, compatible with QEMU and all hardware)
- **Notifications**: dunst themed to Claude palette (volume/brightness OSD)
- **Screen locker**: i3lock (navy background); auto-locks before suspend via xss-lock
- **Auto-mount**: udiskie (systray, auto-mounts removable media)
- **Blue light filter**: redshift (London defaults; edit `~/.config/redshift/redshift.conf`)
- **GTK theme**: Adwaita-dark + Papirus-Dark icons

---

## Keybindings

All bindings use the **Super** key (Windows/Cmd key).

| Binding | Action |
|---|---|
| `Super + Return` | Open kitty terminal |
| `Super + Space` | rofi app launcher |
| `Super + E` | lf file manager (in kitty) |
| `Super + B` | qutebrowser |
| `Super + Shift + E` | Power menu (logout/reboot/shutdown/sleep) |
| `Super + L` | Lock screen |
| `Super + Shift + Q` | Close focused window |
| `Super + Shift + K` | Kill focused window |
| `Super + {H,J,K,L}` | Focus window (vim directions) |
| `Super + Shift + {H,J,K,L}` | Swap window |
| `Alt + Tab / Alt + Shift + Tab` | Cycle windows forward/back |
| `Super + [ / ]` | Focus prev/next desktop |
| `Super + grave / Tab` | Focus last node / last desktop |
| `Super + {O,I}` | Focus older/newer in history |
| `Super + {P,,,}` | Focus parent/first/second child |
| `Super + {1-9}` | Switch to workspace |
| `Super + Shift + {1-9}` | Move window to workspace |
| `Super + T / Shift + T` | Set tiled / pseudo_tiled |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + Space` | Toggle floating |
| `Super + M` | Cycle desktop layout |
| `Super + R` | Rotate node tree 90° |
| `Super + Y` | Send newest marked to newest preselected |
| `Super + G` | Swap with biggest window |
| `Super + Ctrl + {H,J,K,L}` | Preselect direction |
| `Super + Ctrl + {1-9}` | Preselect split ratio |
| `Super + Ctrl + Space` | Cancel preselection |
| `Super + Ctrl + {M,X,Y,Z}` | Toggle marked/locked/sticky/private |
| `Super + Alt + {H,J,K,L}` | Expand window |
| `Super + Alt + Shift + {H,J,K,L}` | Shrink window |
| `Super + Arrow keys` | Move floating window |
| `Super + Shift + R` | Restart bspwm |
| `Super + Alt + Escape` | Quit bspwm |
| `Super + Escape` | Reload sxhkd config |
| `Print` | Screenshot — region (flameshot) |
| `Super + Print` | Screenshot — full screen |
| `XF86AudioRaiseVolume` | Volume +5% (with OSD) |
| `XF86AudioLowerVolume` | Volume -5% (with OSD) |
| `XF86AudioMute` | Toggle mute (with OSD) |
| `XF86MonBrightnessUp/Down` | Brightness ±10% (with OSD) |
| `XF86AudioPlay/Next/Prev` | Media playback (playerctl) |

---

## Live Session Credentials

| Account | Password |
|---|---|
| `axyl` | `axyl` |
| `root` | `toor` |

`axyl` has passwordless sudo for the live session.

---

## Post-Install

After installing Axyl to disk:

1. Reboot into the installed system
2. Log in and run:
   ```bash
   sudo axyl-setup
   ```
3. Reboot

`axyl-setup` enables greetd and sets up XDG user directories.

---

## Changelog

- **2026-08-18** — Restructured project: Dockerfiles moved to `docker/`, shared dotfiles promoted to top-level `skel/`, pacman config riced (Color, ILoveCandy, VerbosePkgLists); expanded keybindings (window cycling, desktop navigation, preselect, resize expand/shrink, floating move); `setup.sh` updated for Docker-based workflow; both variants build via Docker
- **2026-08-17** — Added Artix/runit variant; screen locker, volume/brightness OSD, bluetooth, PDF/image viewers, auto-mount, blue light filter; switched to greetd, PipeWire, qutebrowser, lf, zsh + Oh My Zsh
- **2026-08-15** — Initial release: bspwm + polybar + rofi + kitty + neovim + Claude color scheme
