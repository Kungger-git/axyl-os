# Axyl Linux

Axyl is a custom Linux live/install ISO built with `archiso`. It boots directly into a fully configured **bspwm** desktop themed with the Claude color scheme — dark navy backgrounds (`#1a1a2e`) and warm coral accents (`#d97757`). On first boot a terminal opens automatically, guiding the user through installation. Everything from the window manager to the editor to the shell prompt is pre-configured and ready to use.

Two variants are available:

| Variant | Init system | UEFI bootloader |
|---|---|---|
| `arch` | systemd | systemd-boot |
| `artix` | runit | GRUB |

Both build inside Docker — no native Arch or Artix host required.

---

## Build Requirements

- **Docker** with the daemon running
- Outbound HTTPS to GitHub (the build clones Oh My Zsh and plugins during `customize_airootfs.sh`)

---

## How to Build

```bash
# Arch variant (systemd)
./build.sh arch

# Artix variant (runit)
./build.sh artix
```

The script rebuilds the Docker builder image from scratch on every run, then runs `mkarchiso` inside the container. The finished ISO is written to `./axyl-out/`.

### Test in QEMU

```bash
# BIOS
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G -boot d

# UEFI (requires edk2-ovmf on host)
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

### Flash to USB

```bash
sudo bash flash.sh ./axyl-out/axyl-*.iso /dev/sdX
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
| `Super + Shift + {H,J,K,L}` | Move window |
| `Super + Ctrl + {H,J,K,L}` | Resize window |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + Space` | Toggle floating |
| `Super + M` | Toggle monocle layout |
| `Super + R` | Rotate node tree 90° |
| `Super + {1–9}` | Switch to workspace |
| `Super + Shift + {1–9}` | Move window to workspace |
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

- **2026-08-18** — Both variants now build via Docker (no native Arch host required); added `Dockerfile.arch`; `build.sh` no longer requires `sudo`
- **2026-08-17** — Added Artix/runit variant (`Dockerfile.artix`, `artixiso/` override layer); added screen locker (i3lock + xss-lock), volume/brightness OSD (dunstify), bluetooth (bluez + blueman), PDF viewer (zathura), image viewer (nsxiv), auto-mount (udiskie), blue light filter (redshift); switched to greetd autologin; switched audio stack to PipeWire; switched browser to qutebrowser; switched file manager to lf; added zsh + Oh My Zsh
- **2026-08-15** — Initial release: bspwm + polybar + rofi + kitty + neovim + Claude color scheme
