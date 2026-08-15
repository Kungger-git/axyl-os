# Axyl Linux

Axyl is an opinionated Arch Linux live/install ISO built with `archiso`. It boots directly into a fully configured **bspwm** desktop themed with the Claude color scheme — dark navy backgrounds (`#1a1a2e`) and warm coral accents (`#d97757`). On first boot a terminal opens automatically, guiding the user through installation via `archinstall` or a manual shell. Everything from the window manager to the editor to the shell prompt is pre-configured and ready to use.

---

## Build Requirements

The following packages must be installed on the **Arch Linux build host**:

| Package | Purpose |
|---|---|
| `archiso` | ISO build framework |
| `mkinitcpio` | Initramfs builder |
| `dosfstools` | FAT filesystem tools for EFI partition |
| `e2fsprogs` | ext2/3/4 filesystem tools |
| `libisoburn` (`xorriso`) | ISO 9660 writer |
| `squashfs-tools` | squashfs compression |
| `grub` | UEFI EFI image generation (build-host dep) |
| `git` | AUR tarball pre-download |

Install all at once:
```bash
sudo pacman -S archiso mkinitcpio dosfstools e2fsprogs libisoburn squashfs-tools grub git
```

---

## How to Build

### Step 1 — Install build dependencies

Run once on a fresh Arch Linux build host:

```bash
chmod +x setup.sh
sudo ./setup.sh
```

Installs: `archiso`, `mkinitcpio`, `dosfstools`, `e2fsprogs`, `libisoburn`, `squashfs-tools`, `grub`, `git`. Optionally installs QEMU + OVMF for ISO testing (prompted).

### Step 2 — Build the ISO

A single script handles AUR setup and the ISO build:

```bash
chmod +x build.sh
sudo ./build.sh
```

`build.sh` will:
1. Clone `paru-bin` and `brave-bin` from AUR into `archiso/airootfs/root/aur-cache/` (skips if already present)
2. Clean the previous work directory
3. Run `mkarchiso` and write the ISO to `/tmp/axyl-out/`

> **Note**: `brave-bin`'s PKGBUILD fetches the Brave release binary (~350 MB) during the build, so the build host needs outbound HTTPS.

### Manual build (without the script)

```bash
# Pre-download AUR tarballs
mkdir -p archiso/airootfs/root/aur-cache
git clone --depth=1 https://aur.archlinux.org/paru-bin.git  archiso/airootfs/root/aur-cache/paru-bin
git clone --depth=1 https://aur.archlinux.org/brave-bin.git archiso/airootfs/root/aur-cache/brave-bin

# Build
sudo mkarchiso -v -w /tmp/axyl-work -o /tmp/axyl-out ./archiso/
```

### Test in QEMU

```bash
# BIOS
qemu-system-x86_64 -cdrom /tmp/axyl-out/*.iso -m 2G -boot d

# UEFI (requires edk2-ovmf: sudo pacman -S edk2-ovmf)
qemu-system-x86_64 -cdrom /tmp/axyl-out/*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

---

## Key Features

- **Window manager**: bspwm with 9 workspaces, 2px borders, 8px gaps
- **Color scheme**: Claude palette — `#1a1a2e` background, `#d97757` accent, `#e6e1d8` foreground
- **Login manager**: ly with doom animation, auto-login as `axyl`
- **Bar**: polybar — workspaces, window title, CPU, memory, volume, network, clock
- **App launcher**: rofi (drun/run/window modes)
- **Terminal**: kitty with JetBrains Mono 12pt and full Claude 16-color palette
- **Browser**: Brave (built from AUR during ISO creation; `paru` available for further AUR packages)
- **Editor**: neovim with custom Claude color scheme (pure lua, no plugins)
- **File manager**: thunar with gvfs and archive support
- **Media**: mpv
- **Audio**: PulseAudio with pamixer (hotkeys) and pavucontrol (GUI)
- **Compositor**: picom (xrender backend, universally compatible; see picom.conf to enable glx + dual_kawase)
- **Notifications**: dunst themed to Claude palette
- **GTK theme**: Adwaita-dark + Papirus-Dark icons

---

## Keybindings

All bindings use the **Super** key (Windows/Cmd key).

| Binding | Action |
|---|---|
| `Super + Return` | Open kitty terminal |
| `Super + Space` | rofi app launcher |
| `Super + E` | Thunar file manager |
| `Super + B` | Brave browser |
| `Super + Shift + Q` | Close focused window |
| `Super + Shift + K` | Kill focused window |
| `Super + {H,J,K,L}` | Focus window (vim directions) |
| `Super + Shift + {H,J,K,L}` | Move window |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + Space` | Toggle floating |
| `Super + M` | Toggle monocle layout |
| `Super + R` | Rotate node tree 90° |
| `Super + {1–9}` | Switch to workspace |
| `Super + Shift + {1–9}` | Move window to workspace |
| `Super + Ctrl + {H,J,K,L}` | Resize window |
| `Super + Shift + R` | Restart bspwm |
| `Super + Alt + Escape` | Quit bspwm |
| `Super + Escape` | Reload sxhkd config |
| `Print` | Screenshot (region — flameshot) |
| `Super + Print` | Screenshot (full screen) |
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume -5% |
| `XF86AudioMute` | Toggle mute |
| `XF86MonBrightnessUp/Down` | Brightness ±10% |
| `XF86AudioPlay/Next/Prev` | Media playback |

---

## Post-Install

After installing Axyl to disk with `archinstall`:

1. Reboot into your installed system
2. Log in and run:
   ```bash
   sudo axyl-setup
   ```
3. Reboot

`axyl-setup` enables the ly display manager and sets up XDG user directories. `paru` is already installed for AUR packages.

**Live session credentials**:
- User: `axyl` / Password: `axyl`
- Root password: `toor`

---

## Changelog

- **2026-08-15** — Initial release: bspwm + ly + polybar + rofi + kitty + brave + neovim + Claude color scheme