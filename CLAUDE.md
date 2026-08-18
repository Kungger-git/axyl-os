# CLAUDE.md — Axyl Linux ISO (bspwm / Arch + Artix)

This file is the authoritative reference for all future Claude sessions in this repository. Follow every rule here precisely and consistently.

---

## Project Overview

**Axyl Linux** is a custom Linux live ISO built with `archiso`. It boots directly into a fully configured bspwm desktop with a dark navy/coral "Claude" color scheme, greetd autologin, Oh My Zsh, polybar, and an interactive installer terminal. Two variants are supported:

| Variant | Init system | UEFI bootloader | Build method |
|---|---|---|---|
| `arch` | systemd | systemd-boot | Docker (`Dockerfile.arch`), no root needed |
| `artix` | runit | GRUB | Docker (`Dockerfile.artix`), no root needed |

**Build command:** `./build.sh [arch|artix]` — defaults to `arch`.

**Editing environment:** Windows (VS Code / OneDrive). **Build environment:** separate Arch Linux machine (arch variant) or any Linux machine with Docker (artix variant). Files are edited on Windows.

---

## Repository Layout

The `archiso/` tree is the base for both variants. `artixiso/` is an **override layer**: `build.sh artix` merges with `cp -rT archiso/ tmp/ && cp -rT artixiso/ tmp/`, so every file in `artixiso/` silently replaces its counterpart in `archiso/`. Files absent from `artixiso/` are taken verbatim from `archiso/`.

```
archiso/
  profiledef.sh                      ← ISO metadata, bootmodes, compression, file_permissions
  packages.x86_64                    ← every package installed in the live system
  pacman.conf                        ← mirrors and repos used during the archiso build
  airootfs/                          ← overlay: copied verbatim into the live rootfs
    etc/
      greetd/config.toml             ← display manager config (autologin via [initial_session])
      mkinitcpio.conf                ← live initramfs config (overrides any drop-in)
      mkinitcpio.conf.d/archiso.conf ← comment-only drop-in (harmless)
      skel/                          ← copied to /home/axyl/ by useradd -m
        .bash_profile                ← sources .bashrc (POSIX [ ] only, no [[ ]])
        .bashrc                      ← bash aliases/exports (POSIX case, no [[ ]])
        .zshrc                       ← Oh My Zsh config, sourced by zsh login shell
        .xinitrc                     ← manual startx fallback (not used by greetd)
        .gtkrc-2.0                   ← GTK2 theme (Arc-Dark + Papirus-Dark)
        .config/
          bspwm/bspwmrc              ← WM config + full autostart (must be executable)
          bspwm/wallpaper.jpg        ← desktop wallpaper (feh --bg-fill)
          sxhkd/sxhkdrc              ← all keybindings
          polybar/config.ini         ← bar config (Font Awesome icons as raw UTF-8 bytes)
          polybar/launch.sh          ← kills old instance, starts polybar axyl
          rofi/config.rasi           ← app launcher + power menu theme
          kitty/kitty.conf           ← terminal emulator config
          picom/picom.conf           ← compositor (xrender backend for QEMU compat)
          dunst/dunstrc              ← notification daemon
          nvim/init.lua              ← neovim config (no plugin manager)
          gtk-3.0/settings.ini       ← GTK3 theme (Arc-Dark + Papirus-Dark)
          zathura/zathurarc          ← PDF viewer theme (Claude palette)
          redshift/redshift.conf     ← blue light filter (manual location, London defaults)
    root/
      customize_airootfs.sh          ← chroot hook: runs after packages installed
    usr/
      local/
        bin/
          start-bspwm-session        ← X session entry point (called by greetd/startx)
          axyl-install               ← interactive installer menu (opens in kitty)
          axyl-setup                 ← post-install helper
          axyl-powermenu             ← rofi power menu (logout/reboot/shutdown/sleep)
          axyl-lock                  ← i3lock wrapper (navy background, --nofork)
          axyl-osd-volume            ← volume OSD helper (pamixer + dunstify progress bar)
          axyl-osd-brightness        ← brightness OSD helper (brightnessctl + dunstify)
  efiboot/
    loader/loader.conf               ← systemd-boot loader config
    loader/entries/
      01-axyl-x86_64-linux.conf      ← UEFI boot entry
  syslinux/                          ← BIOS bootloader files
build.sh                             ← wrapper: cleans work/out dirs, calls mkarchiso
flash.sh                             ← writes ISO to USB with dd (USB drives only)
README.md                            ← user-facing documentation
Dockerfile.artix                     ← Docker build environment for the artix variant
artixiso/                            ← override layer: files here win over archiso/
  profiledef.sh                      ← Artix overrides (runit label, GRUB bootmode)
  pacman.conf                        ← Artix repos + Arch [extra] for missing packages
  packages.x86_64                    ← Artix package list (runit packages, no systemd)
  grub/
    grub.cfg                         ← GRUB UEFI menu (BIOS uses archiso/syslinux/)
  airootfs/
    etc/
      mkinitcpio.conf                ← MODULES includes isofs (required for Artix)
    root/
      customize_airootfs.sh          ← runit services, mkinitcpio preset bypass
    usr/local/bin/
      axyl-install                   ← Artix installer guide (pacstrap/genfstab/arch-chroot)
      axyl-powermenu                 ← loginctl reboot/poweroff/suspend (NOT systemctl)
      axyl-setup                     ← runit greetd enablement (NOT systemctl)
```

---

## Build System

### profiledef.sh — Current Values

```bash
iso_name="axyl"
iso_label="AXYL_$(date +%Y%m)"          # used as archisolabel= on kernel cmdline
iso_publisher="Axyl Linux"
iso_application="Axyl Linux Live/Install CD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"                       # must match archisobasedir= in boot entry
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '512K')
```

`file_permissions` — all executables that need 755 in the live system:

```bash
declare -A file_permissions=(
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/etc/skel/.xinitrc"]="0:0:755"
    ["/etc/skel/.config/bspwm/bspwmrc"]="0:0:755"
    ["/etc/skel/.config/polybar/launch.sh"]="0:0:755"
    ["/usr/local/bin/start-bspwm-session"]="0:0:755"
    ["/usr/local/bin/axyl-install"]="0:0:755"
    ["/usr/local/bin/axyl-setup"]="0:0:755"
    ["/usr/local/bin/axyl-powermenu"]="0:0:755"
    ["/usr/local/bin/axyl-lock"]="0:0:755"
    ["/usr/local/bin/axyl-osd-volume"]="0:0:755"
    ["/usr/local/bin/axyl-osd-brightness"]="0:0:755"
)
```

`file_permissions` is applied by mkarchiso during the build, before the chroot runs. Paths are relative to the **live rootfs**, not the repo. The skel files are set to 755 here so `useradd -m` copies them with the execute bit preserved.

### mkinitcpio.conf — Current Values

**Arch variant** (`archiso/airootfs/etc/mkinitcpio.conf`):
```
MODULES=(loop squashfs overlay)
BINARIES=()
FILES=()
HOOKS=(base udev modconf archiso archiso_loop_mnt kms block filesystems keyboard)
COMPRESSION="xz"
```

**Artix variant** (`artixiso/airootfs/etc/mkinitcpio.conf`) — identical except MODULES:
```
MODULES=(loop squashfs overlay isofs)
BINARIES=()
FILES=()
HOOKS=(base udev modconf archiso archiso_loop_mnt kms block filesystems keyboard)
COMPRESSION="xz"
```

**Why `isofs` is required for Artix but not Arch:** On Arch, the `mkinitcpio-archiso` install hook calls `add_module 'isofs'` internally. On Artix, the live system uses an older `mkinitcpio` from `[world]` that does not always execute Arch-format install hooks completely. Without `isofs` in the initramfs, the `archiso` hook can find the CD-ROM device by label but cannot mount the ISO 9660 filesystem — resulting in kernel panic `VFS: Unable to mount root fs on unknown-block(0,0)`.

**Hook rules (non-negotiable):**
- `archiso` and `archiso_loop_mnt` come from the **`mkinitcpio-archiso`** package (not `archiso`). Always have `mkinitcpio-archiso` in `packages.x86_64`.
- `archiso_shutdown` was **removed** from `mkinitcpio-archiso` in the current version. Never add it.
- `archiso_kms` was **deprecated**. Use the standard `kms` hook instead.
- Hook order matters: `archiso` and `archiso_loop_mnt` must appear before `block`.
- `MODULES=(loop squashfs overlay)` — all three are required for the live squashfs to mount. Artix also requires `isofs` (see above).
- This file is at `airootfs/etc/mkinitcpio.conf` (a direct config, not a drop-in). It takes precedence over any drop-in in `mkinitcpio.conf.d/`.

### Bootloaders

**UEFI — systemd-boot** (`uefi.systemd-boot`):
- Config in `archiso/efiboot/loader/loader.conf` and `efiboot/loader/entries/01-axyl-x86_64-linux.conf`
- Kernel cmdline: `archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=1G`
- `cow_spacesize=1G` — writable overlay size in RAM
- `%INSTALL_DIR%` = `arch` (matches `install_dir` in profiledef.sh)
- `%ARCHISO_LABEL%` = substituted from `iso_label` at build time
- systemd-boot requires **no grub package on the build host**

**BIOS — syslinux** (`bios.syslinux`):
- `syslinux` package must be in `packages.x86_64` AND on the build host

### customize_airootfs.sh — Execution Order

This script runs in a chroot of the live rootfs after all packages are installed. Network access is available (inherits host network namespace via arch-chroot). **Order matters:**

1. `pacman-key --init && pacman-key --populate archlinux` — MUST be first
2. Locale, timezone, hostname, /etc/hosts
3. `systemctl enable` — NetworkManager, greetd, acpid; `set-default graphical.target`
4. **Git clone Oh My Zsh into `/etc/skel/.oh-my-zsh/`** — MUST be before `useradd -m` so it is copied to `/home/axyl/`
5. `useradd -m -G ... -s /bin/zsh axyl` — copies all of `/etc/skel/` to `/home/axyl/`
6. Set passwords, write sudoers, run xdg-user-dirs-update
7. `paccache -r -k0` — clean pacman cache to reduce ISO size

### greetd Config

```toml
[terminal]
vt = 2

[default_session]
command = "agreety --cmd /usr/local/bin/start-bspwm-session"
user = "greeter"

[initial_session]
command = "startx /usr/local/bin/start-bspwm-session -- :0 vt2 -keeptty -nolisten tcp"
user = "axyl"
```

**Critical:** `[initial_session]` is the autologin mechanism. `[default_session]` is the fallback greeter shown after the session ends. Using only `[default_session]` for autologin is WRONG — greetd will show a blank screen waiting for a greeter that never runs.

`agreety` ships with the `greetd` package. It creates a `greeter` user/group on install.

### Session Startup Chain

```
greetd (PAM session for axyl)
  └─ startx /usr/local/bin/start-bspwm-session -- :0 vt2
       └─ X server (:0, vt2)
       └─ start-bspwm-session
            ├─ xset, xsetroot (keyboard rate, cursor, DPMS off)
            ├─ chmod +x ~/.config/bspwm/bspwmrc   ← safety net for execute bit
            └─ exec dbus-run-session /usr/bin/bspwm
                 └─ bspwm (auto-execs ~/.config/bspwm/bspwmrc if executable)
                      └─ bspwmrc autostart:
                           ├─ sxhkd &
                           ├─ # picom (commented out; enable for shadows)
                           ├─ feh --bg-fill wallpaper.jpg
                           ├─ pipewire &, wireplumber &, pipewire-pulse &
                           ├─ [wait for pactl readiness, 5 × 300ms]
                           ├─ ~/.config/polybar/launch.sh &
                           ├─ dunst &
                           ├─ [2s deferred] polkit-gnome, nm-applet, numlockx, xss-lock
                           └─ # 5s block removed (copyq/blueman/udiskie/redshift)
```

bspwm uses `execv()` to run bspwmrc with its shebang (`#!/usr/bin/env bash`). If bspwmrc is not executable, bspwm silently skips it — no sxhkd, no polybar, no keybindings. The `chmod +x` in `start-bspwm-session` is a required safety net.

---

## Build Requirements

### Host requirement

Both variants build inside Docker — no native Arch/Artix install required. The only host dependency is Docker with the daemon running.

### Dockerfile.arch — build-host packages

These are installed into the `archlinux:latest` Docker container:

```
archiso          ← provides mkarchiso
dosfstools       ← mkfs.fat for the ESP partition
e2fsprogs        ← mkfs.ext4
libisoburn       ← xorriso, creates the ISO image
squashfs-tools   ← mksquashfs for the rootfs image
syslinux         ← BIOS bootloader generation
mkinitcpio       ← builds the initramfs
git              ← customize_airootfs.sh clones Oh My Zsh
```

`systemd` (already in `archlinux:latest` base) provides `systemd-bootx64.efi`, which mkarchiso needs on the build host for the `uefi.systemd-boot` bootmode. `grub` is NOT needed.

### Network requirement during build

`customize_airootfs.sh` clones three git repositories from GitHub:
- `https://github.com/ohmyzsh/ohmyzsh.git` → `/etc/skel/.oh-my-zsh`
- `https://github.com/zsh-users/zsh-autosuggestions.git` → `.oh-my-zsh/custom/plugins/zsh-autosuggestions`
- `https://github.com/zsh-users/zsh-syntax-highlighting.git` → `.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`

The Docker container inherits host network, so DNS and TCP work transparently.

---

## Build Commands

```bash
# Arch variant (Docker, no sudo needed)
./build.sh arch

# Artix variant (Docker, no sudo needed)
./build.sh artix

# Flash to USB
sudo bash flash.sh ./axyl-out/axyl-*.iso /dev/sdX

# Test BIOS boot in QEMU
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G -boot d

# Test UEFI boot in QEMU (requires edk2-ovmf on build host)
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

---

## Package List Reference

`archiso/packages.x86_64` — every package here is installed in the live system. Groups:

| Group | Key packages | Purpose |
|---|---|---|
| Base | base, base-devel, linux, linux-firmware, linux-headers, intel-ucode, amd-ucode | Core system |
| Initramfs | mkinitcpio, **mkinitcpio-archiso**, archlinux-keyring | Live boot hooks |
| Bootloaders | grub, efibootmgr, mtools, os-prober, syslinux | BIOS + UEFI boot |
| Xorg | xorg-server, xorg-xinit, xorg-xrandr, xorg-xsetroot, xorg-xrdb, xorg-xset, xorg-xkill, xorg-xdpyinfo, xorg-xauth, xterm | Display server |
| GPU | xf86-video-vesa, xf86-video-amdgpu, xf86-video-nouveau, mesa, libva-mesa-driver, vulkan-radeon, vulkan-intel | GPU support |
| WM | bspwm, sxhkd, picom, feh, dunst, libnotify, xdg-user-dirs, xdg-utils, xdg-desktop-portal, xdg-desktop-portal-gtk | Window manager stack |
| Desktop | greetd, polybar, rofi, kitty | Display manager + bar + launcher + terminal |
| Editors | neovim, vim, nano | Text editors |
| Files | lf | TUI file manager (opens nsxiv/zathura/mpv via mime) |
| Media | mpv, ffmpeg, imagemagick | Media playback + processing |
| Audio | **pipewire**, pipewire-alsa, **pipewire-pulse**, **wireplumber**, gst-plugin-pipewire, alsa-utils, alsa-firmware, pavucontrol, pamixer, playerctl | PipeWire audio stack (PulseAudio-compatible) |
| Network | networkmanager, network-manager-applet, wpa_supplicant, openssh, iptables | Network |
| Dev tools | git, curl, wget, python, python-pip, jq, pacman-contrib | Dev + scripting |
| Fonts | ttf-jetbrains-mono, ttf-font-awesome, noto-fonts, noto-fonts-emoji, ttf-liberation, terminus-font | All fonts used by polybar/kitty/rofi |
| Theme | papirus-icon-theme, gnome-themes-extra, lxappearance, adwaita-icon-theme, polkit-gnome | GTK theme (Adwaita-dark) + icons + polkit agent |
| Shell | zsh | Oh My Zsh runtime |
| Utilities | **qutebrowser**, pv, btop, fastfetch, flameshot, xclip, xdotool, brightnessctl, numlockx, zip, unzip, p7zip, inxi, acpi, acpid, procps-ng, psmisc, util-linux | General tools |
| Security | i3lock, xss-lock | Screen locker + auto-lock on suspend |
| Desktop extras | udiskie, udisks2, redshift | Auto-mount, blue-light filter |
| Bluetooth | bluez, bluez-utils, blueman | Bluetooth stack + GUI applet |
| Viewers | zathura, zathura-pdf-mupdf, nsxiv | PDF + image viewers |
| Installer | arch-install-scripts, archinstall, reflector, parted, gptfdisk, dosfstools, e2fsprogs, btrfs-progs, cryptsetup, lvm2, ntfs-3g, polkit | Target install tools |

---

## Color Scheme — Claude Palette

| Role | Hex | Used in |
|---|---|---|
| Background | `#1a1a2e` | All app backgrounds |
| Background Alt | `#16213e` | Input bars, tab backgrounds |
| Foreground | `#e6e1d8` | Primary text |
| Muted | `#6e7290` | Inactive/secondary text |
| Accent (coral) | `#d97757` | Borders, focused, prompt, cursor |
| Accent Alt | `#e8927c` | Presel feedback, hover states |
| Red | `#ff5555` | Urgent, errors |

---

## Keybindings Summary

| Binding | Action |
|---|---|
| `super + Return` | kitty terminal |
| `super + space` | rofi app launcher |
| `super + e` | lf file manager (in kitty) |
| `super + b` | qutebrowser |
| `super + shift + e` | axyl-powermenu (logout/reboot/shutdown/sleep) |
| `super + l` | lock screen (axyl-lock → i3lock) |
| `super + shift + q` | close focused window |
| `super + shift + k` | kill focused window |
| `super + f` | toggle fullscreen |
| `super + shift + space` | toggle floating |
| `super + m` | cycle desktop layout |
| `super + r` | rotate node 90° |
| `super + Escape` | reload sxhkd |
| `super + shift + r` | restart bspwm |
| `super + alt + Escape` | quit bspwm |
| `super + {h,j,k,l}` | focus west/south/north/east |
| `super + shift + {h,j,k,l}` | move node west/south/north/east |
| `super + ctrl + {h,j,k,l}` | resize node |
| `super + {1-9}` | focus workspace |
| `super + shift + {1-9}` | move node to workspace |
| `Print` | flameshot gui (region screenshot) |
| `super + Print` | flameshot screen -c (full screen) |
| `XF86Audio*` | axyl-osd-volume (pamixer + dunstify OSD) |
| `XF86Brightness*` | axyl-osd-brightness (brightnessctl + dunstify OSD) |

---

---

## Artix Variant — Build System

### Overview

The artix variant builds inside Docker so it does not require an Artix host. `build.sh artix` always rebuilds the Docker image from scratch (`docker rmi` then `docker build`) to pick up any `Dockerfile.artix` changes, then merges `archiso/` + `artixiso/` into a temp profile and runs `mkarchiso` inside the container.

### Dockerfile.artix — Required Build-Host Packages

These are installed into the Docker container (the build host), not the live system:

```
archiso             ← provides mkarchiso (from Arch [extra])
arch-install-scripts ← provides genfstab (from Arch [extra])
dosfstools          ← mkfs.fat for the ESP partition
e2fsprogs           ← mkfs.ext4
libisoburn          ← xorriso, creates the ISO image
squashfs-tools      ← mksquashfs for the rootfs image
syslinux            ← BIOS bootloader generation
grub                ← grub-mkstandalone for uefi-x64.grub.esp UEFI image
mkinitcpio          ← builds the initramfs (from Arch [extra])
git                 ← customize_airootfs.sh clones Oh My Zsh
```

**Critical:** `grub` MUST be in the Dockerfile. The `uefi-x64.grub.esp` bootmode calls `grub-mkstandalone` on the build host to create the EFI image. Without `grub` on the build host, UEFI setup fails.

The Arch `[extra]` repo is added to the container's `/etc/pacman.conf` with `SigLevel = Never`. The section **must be named `[extra]`** — pacman fetches `<section-name>.db` from the mirror server; a custom name like `[arch-extra]` would request a non-existent `arch-extra.db` and 404.

### artixiso/pacman.conf — Repo Structure

```ini
[system]   ← Artix core (≈ Arch core, rebuilt without systemd)
[world]    ← Artix extra (≈ Arch extra, rebuilt without systemd)
[galaxy]   ← Artix community

[extra]    ← Arch's extra repo — for mkinitcpio-archiso and arch-install-scripts
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
SigLevel = Never
```

All Artix repos use `Include = /etc/pacman.d/mirrorlist` — the container's native mirrorlist from the `artixlinux/artixlinux:base-runit` Docker image. Do NOT replace or overwrite this mirrorlist; it is the same one that successfully downloads packages in the `docker build` step.

**`[artix]` repo is NOT present** — it is an internal Artix repo that is not externally mirrored. All packages needed (including `artix-keyring`) are in `[system]`.

### artixiso/packages.x86_64 — Key Differences from Arch

| Arch package | Artix equivalent | Notes |
|---|---|---|
| `archlinux-keyring` | `artix-keyring` | Artix uses its own GPG keyring |
| (none) | `dbus-runit`, `elogind-runit`, `networkmanager-runit`, `greetd-runit`, `acpid-runit`, `bluez-runit` | Every daemon needs its `-runit` companion |
| `systemd` (implicit) | `elogind`, `elogind-runit` | Seat/session management; provides `loginctl` |
| `reflector` | *(absent)* | Reflector uses Arch-mirror API only; non-functional on Artix |
| `artix-install-scripts` | `arch-install-scripts` | `artix-install-scripts` does NOT exist in public Artix repos |
| `archinstall` | *(absent)* | Arch-specific guided installer; not available for Artix |

**runit service pairs** — every daemon enabled in `customize_airootfs.sh` needs both packages:

| Service name | Base package | runit package |
|---|---|---|
| `dbus` | `dbus` | `dbus-runit` |
| `elogind` | `elogind` | `elogind-runit` |
| `NetworkManager` | `networkmanager` | `networkmanager-runit` |
| `greetd` | `greetd` | `greetd-runit` |
| `acpid` | `acpid` | `acpid-runit` |
| `bluetoothd` | `bluez` | `bluez-runit` |

### artixiso/profiledef.sh — Key Differences

```bash
iso_label="AXYL_ARTIX_$(date +%Y%m)"   # distinct label from the Arch variant
bootmodes=('bios.syslinux' 'uefi-x64.grub.esp')  # GRUB, not systemd-boot
```

`uefi.systemd-boot` MUST NOT be used — it requires `systemd-bootx64.efi` from the `systemd` package, which is not installed on Artix. The build fails with `install: cannot stat '.../systemd-bootx64.efi': No such file or directory`.

### artixiso/grub/grub.cfg — GRUB UEFI Config

mkarchiso's `uefi-x64.grub.esp` bootmode substitutes `%INSTALL_DIR%` and `%ARCHISO_LABEL%` in this file before embedding it with `grub-mkstandalone`.

**Critical path rule:** microcode images are NOT in the `x86_64` subdirectory:

```
# CORRECT
initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img \
       /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img

# WRONG — causes "file not found" at GRUB boot
initrd /%INSTALL_DIR%/boot/x86_64/intel-ucode.img ...
```

The kernel and initramfs ARE in `x86_64/`. The ucode images are directly in `boot/`.

**Font loading:** `loadfont unicode` must appear before `terminal_output gfxterm`. Without it, GRUB renders box-drawing characters (borders) as `?`.

### artixiso/airootfs/root/customize_airootfs.sh — Execution Order

1. `pacman-key --init && pacman-key --populate artix` — MUST be first; uses Artix keyring
2. Locale, timezone, hostname, /etc/hosts
3. **mkinitcpio initramfs rebuild** — MUST be early (see below)
4. runit service symlinks via `ln -s /etc/runit/sv/<svc> /etc/runit/runsvdir/default/`
5. Git clone Oh My Zsh — MUST be before `useradd -m`
6. `groupadd -f` for wheel/audio/video/input/storage/optical/network — MUST be before `useradd`
7. `useradd -m -G wheel,audio,video,input,storage,optical,network -s /bin/zsh axyl`
8. Passwords, sudoers, xdg-user-dirs-update, chmod on scripts
9. `paccache -r -k0`

**runit service enablement** — NOT `systemctl enable`. Pattern:
```bash
for svc in dbus elogind NetworkManager greetd acpid bluetoothd; do
    [ -d "/etc/runit/sv/$svc" ] && ln -sf "/etc/runit/sv/$svc" "$RUNIT_DEFAULT/"
done
```

**groupadd -f is required** — Artix's `esysusers` hook may not create `storage` and `optical` groups before `useradd` runs inside the mkarchiso chroot. `groupadd -f` creates them if absent; `-f` makes it a no-op if they already exist.

### mkinitcpio Preset Bypass (Artix-specific)

`mkinitcpio-archiso` (Arch [extra]) installs or modifies `/etc/mkinitcpio.d/linux.preset` to load a drop-in named `archiso` from `mkinitcpio.conf.d/`. Artix's `mkinitcpio` (from `[world]`, older version) generates a `Configuration: archiso` INI-format section header in the merged temp file, then tries to source it as bash — resulting in:

```
/tmp/mkinitcpio.XXXXXX: line 5: Configuration: command not found
==> ERROR: Failed to read configuration
```

This fails as a pacman hook (step 15/25 of the package install phase). mkarchiso continues but no `initramfs-linux.img` is created.

**Fix:** In `customize_airootfs.sh`, call mkinitcpio directly with explicit flags — no preset, no drop-in:

```bash
mkinitcpio \
    -c /etc/mkinitcpio.conf \
    -k /boot/vmlinuz-linux \
    -g /boot/initramfs-linux.img
```

This runs AFTER package installation (inside `customize_airootfs.sh`) and produces the initramfs that mkarchiso copies into the ISO. The step-15 failure is permanent and expected — the `customize_airootfs.sh` rebuild is the authoritative initramfs.

### Power Commands — loginctl, not systemctl

Artix does not install `systemd`. Any script calling `systemctl reboot`, `systemctl poweroff`, or `systemctl suspend` will fail with `command not found`. Use `loginctl` instead (provided by `elogind`):

| Old (Arch) | New (Artix) |
|---|---|
| `systemctl reboot` | `loginctl reboot` |
| `systemctl poweroff` | `loginctl poweroff` |
| `systemctl suspend` | `loginctl suspend` |
| `systemctl enable svc` | `ln -sf /etc/runit/sv/svc /etc/runit/runsvdir/default/` |

Every `archiso/airootfs/usr/local/bin/` script that calls `systemctl` MUST have an override in `artixiso/airootfs/usr/local/bin/`. Currently: `axyl-powermenu`, `axyl-setup`.

### Artix Build Commands

```bash
# Full build (Docker, no sudo needed)
./build.sh artix

# Docker image is always rebuilt — no cache reuse

# Test BIOS boot in QEMU
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G -boot d

# Test UEFI boot in QEMU (requires edk2-ovmf on build host)
qemu-system-x86_64 -cdrom ./axyl-out/axyl-*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

---

## Known Pitfalls

These caused real build or boot failures. Check here before debugging.

### Hook errors (mkinitcpio)

| Symptom | Cause | Fix |
|---|---|---|
| `Hook 'archiso' cannot be found` | `archiso` (build tool) in packages.x86_64 instead of `mkinitcpio-archiso` (hook provider) | Replace `archiso` with `mkinitcpio-archiso` in packages.x86_64 |
| `Hook 'archiso_shutdown' cannot be found` | Hook removed from current mkinitcpio-archiso | Remove `archiso_shutdown` from HOOKS |
| `Hook 'archiso_kms' is deprecated` | Old hook name | Replace `archiso_kms` with `kms` in HOOKS |

### Black screen on boot

| Symptom | Cause | Fix |
|---|---|---|
| Black screen, no cursor | greetd shows nothing | Check greetd/config.toml — must use `[initial_session]` for autologin, not `[default_session]` |
| Black screen, mouse cursor moves, no bar or keybindings | bspwmrc not executing | Execute bit missing on bspwmrc; `chmod +x` in start-bspwm-session is the safety net |
| Black screen after wallpaper expected | feh can't find wallpaper | File extension mismatch — bspwmrc must reference `wallpaper.jpg` not `wallpaper.png` |
| Polybar not starting — `launch.sh: permission denied` | `useradd -m` does not reliably preserve execute bits when copying from `/etc/skel/`, even when `file_permissions` sets the skel file to 755 | Add `chmod +x ~/.config/polybar/launch.sh` in bspwmrc immediately before calling it |
| Bar-background-colored strip where polybar should be | polybar running but invisible | Polybar background matches desktop; check font/module init |

### Polybar

| Symptom | Cause | Fix |
|---|---|---|
| Polybar not starting | PipeWire race condition | bspwmrc starts pipewire/wireplumber/pipewire-pulse, then waits for `pactl info` to succeed before launching polybar |
| Polybar not starting | Empty ramp-volume values | Font Awesome icons must be raw UTF-8 bytes in config.ini — write via script, not text editor that may strip PUA chars |
| `UTF-8 with BOM` fatal error on start | config.ini has UTF-8 BOM | Strip BOM: `$b=[System.IO.File]::ReadAllBytes($f); [System.IO.File]::WriteAllBytes($f,$b[3..($b.Length-1)])` |
| Icons not rendering | Wrong font or missing font fallback | rofi config.rasi sets `font: "JetBrains Mono 11"` so Pango falls back to FA6 for PUA chars |

### Shell / terminal

| Symptom | Cause | Fix |
|---|---|---|
| `bash: [[: command not found` | `[[` is a bash keyword, fails in POSIX mode | Use POSIX `case $- in *i*)` in .bashrc; use `[ -f ... ]` in .bash_profile |
| `command not found: export` on line 1 of .zshrc | UTF-8 BOM prepended — zsh sees BOM+`export` as unknown command | Strip BOM from .zshrc (and any dotfile written by PowerShell); use `[System.Text.UTF8Encoding]::new($false)` for all writes |
| No keybindings after login | sxhkd not started | bspwmrc not running (execute bit missing) |
| Oh My Zsh not found at login | .oh-my-zsh not in /home/axyl/ | Git clone must happen BEFORE useradd -m in customize_airootfs.sh |

### Artix build errors

| Symptom | Cause | Fix |
|---|---|---|
| `Configuration: command not found` during pacman hook (step 15/25) | Artix's mkinitcpio (from `[world]`) generates `Configuration: archiso` INI section header in merged temp file; bash can't source it | In `customize_airootfs.sh`, rebuild initramfs with `mkinitcpio -c /etc/mkinitcpio.conf -k /boot/vmlinuz-linux -g /boot/initramfs-linux.img` — bypasses preset and drop-in entirely |
| `install: cannot stat '.../systemd-bootx64.efi': No such file or directory` | `uefi.systemd-boot` bootmode requires systemd; Artix doesn't have it | Set `bootmodes=('bios.syslinux' 'uefi-x64.grub.esp')` in `artixiso/profiledef.sh`; add `grub` to `Dockerfile.artix` |
| `useradd: group 'storage' does not exist` | Artix `esysusers` hooks don't run inside mkarchiso chroot | Add `groupadd -f` loop for wheel/audio/video/input/storage/optical/network before `useradd` |
| `KERNEL PANIC! VFS: Unable to mount root fs on unknown-block(0,0)` | `isofs` module absent from initramfs; archiso hook finds CD-ROM but can't mount ISO 9660 | Add `isofs` to `MODULES=` in `artixiso/airootfs/etc/mkinitcpio.conf` |
| GRUB borders rendered as `?` | `terminal_output gfxterm` set before loading unicode font | Wrap gfxmode/gfxterm in `if loadfont unicode; then` block |
| GRUB error: `file /arch/boot/x86_64/intel-ucode.img not found` | Microcode images are NOT in the `x86_64` subdirectory | Use `/%INSTALL_DIR%/boot/intel-ucode.img` (no `x86_64`); only vmlinuz and initramfs use the `x86_64/` subdir |
| `systemctl: command not found` in running Artix system | Artix has no systemd | Use `loginctl reboot/poweroff/suspend` instead; enable services with `ln -s /etc/runit/sv/<svc> /etc/runit/runsvdir/default/` |
| Service not starting on boot in installed Artix system | runit service symlink missing | Each daemon needs its `-runit` companion package AND a symlink in `/etc/runit/runsvdir/default/` |

### Font Awesome icons

Font Awesome 6 uses the Unicode Private Use Area (U+E000–U+F8FF). These characters must be written as raw UTF-8 bytes into config files. Pasting them in a text editor on Windows may silently strip or corrupt them. Always verify with:

```bash
grep -cP "[\x80-\xFF]" archiso/airootfs/etc/skel/.config/polybar/config.ini
```

Expected: non-zero. If zero, icons are missing and must be re-written programmatically.

Key codepoints (FA6 Free Solid):

| Icon | Codepoint | Used in |
|---|---|---|
| fa-microchip | U+F2DB | polybar cpu module prefix |
| fa-memory | U+F538 | polybar memory module prefix |
| fa-volume-off | U+F026 | ramp-volume-0, label-muted |
| fa-volume-low | U+F027 | ramp-volume-1 |
| fa-volume-high | U+F028 | ramp-volume-2 |
| fa-wifi | U+F1EB | network-wireless label |
| fa-network-wired | U+F796 | network-wired label |
| fa-clock | U+F017 | date module prefix |
| fa-right-from-bracket | U+F2F5 | powermenu logout |
| fa-arrows-rotate | U+F021 | powermenu reboot |
| fa-power-off | U+F011 | powermenu shutdown |
| fa-moon | U+F186 | powermenu sleep |

---

## Live System Credentials

| Account | Password | Notes |
|---|---|---|
| axyl | axyl | Default user, passwordless sudo, shell = /bin/zsh |
| root | toor | Root account |

---

## Task Tracking (TODOs)

**Every task Claude performs must be tracked as a TODO.**

- Write the TODO list with `TodoWrite` before starting any work.
- Mark each item complete immediately when done — do not batch completions.
- Never leave a TODO open at the end of a session without noting its status.
- TODOs must be granular: one action per item.

---

## Dependency Management

**Never assume a dependency is available. Verify it.**

For every new feature:
1. Identify every binary, library, or config the feature references.
2. Trace each to its Arch package name.
3. Add missing packages to `packages.x86_64`.
4. Verify no circular or conflicting packages are introduced.

After adding any config, hook, or script, audit its runtime dependencies before closing the task.

---

## Coding Rules

- Shell scripts: `#!/usr/bin/env bash` and `set -euo pipefail`.
- `.bashrc` and `.bash_profile`: use only POSIX constructs (`case`, `[ ]`). Never `[[ ]]` — these files may be sourced in a POSIX-mode shell.
- No comments unless the WHY is non-obvious.
- No placeholder or stub code — every added line must be functional.
- Keep configs minimal: do not add packages or features not explicitly requested.
- Font Awesome icons in text configs must be written as raw UTF-8 bytes (use PowerShell `[char]0xXXXX` or equivalent, not a text editor).
- **PowerShell file writes must NEVER include BOM.** `[System.Text.Encoding]::UTF8` and `[System.IO.File]::WriteAllText` with default encoding both write a UTF-8 BOM. Always use `[System.Text.UTF8Encoding]::new($false)` explicitly:
  ```powershell
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8)
  ```
  BOM causes: polybar `UTF-8 with BOM` fatal error; zsh `command not found: export` on line 1; bash scripts fail to exec (kernel misses `#!` shebang). Always verify with `ReadAllBytes` — first 3 bytes must NOT be `EF BB BF`.

---

## File Structure Checks

Run mentally after every edit session:

- Every binary referenced in `airootfs/etc/skel/**` has a corresponding package in `packages.x86_64`.
- Every script in `airootfs/usr/local/bin/` has an entry in `file_permissions` at 0:0:755.
- `bspwmrc` and `launch.sh` have entries in `file_permissions` at 0:0:755.
- `mkinitcpio.conf` HOOKS contain no deprecated or removed hook names.
- **Arch variant:** `profiledef.sh` bootmodes use `uefi.systemd-boot` for UEFI.
- **Artix variant:** `artixiso/profiledef.sh` bootmodes use `uefi-x64.grub.esp`; `artixiso/grub/grub.cfg` exists; ucode initrd paths use `/%INSTALL_DIR%/boot/intel-ucode.img` (NO `x86_64` subdir).
- `greetd/config.toml` has `[initial_session]` for autologin.
- Any new wallpaper image: extension in `bspwmrc` feh call matches the actual file extension.
- **Artix variant:** Any script in `archiso/airootfs/usr/local/bin/` that calls `systemctl` MUST have an override in `artixiso/airootfs/usr/local/bin/` that uses `loginctl` instead. Currently overridden: `axyl-powermenu`, `axyl-setup`.
- **Artix variant:** Every daemon enabled in `customize_airootfs.sh` must have both a base package AND a `-runit` companion package in `artixiso/packages.x86_64`.

---

## Workflow Checklist

```
[ ] Write TODOs before starting
[ ] Read the codebase and identify files that are no longer needed; delete them
[ ] Identify all new dependencies; add to packages.x86_64
[ ] Edit or create the relevant files
[ ] Verify file structure is still consistent
[ ] Update README.md — always; every task that changes behaviour, commands, files, or defaults must be reflected in README.md
[ ] Mark all TODOs complete (or annotate blockers)
```
