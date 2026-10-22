# Axyl Linux

Axyl is a custom Linux live/install ISO built with `archiso`. It boots into a
pre-configured **Hyprland / Wayland** desktop using the opencode dark palette
(`#0a0a0a` background, `#fab283` accent). The live session starts as user
`axyl`; the installer creates a normal account with a real password and a
greeter on the installed system.

Two variants are available:

| Variant | Init system | UEFI bootloader | Output |
|---|---|---|---|
| `arch` | systemd | systemd-boot | `axyl-out/arch/axyl-arch-*.iso` |
| `artix` | runit | GRUB | `axyl-out/artix/axyl-artix-*.iso` |

Both build inside Docker; no native Arch or Artix host is required.

---

## Build

```bash
# Arch variant (systemd)
./build.sh arch

# Artix variant (runit)
./build.sh artix
```

The first build also builds a vendored `brave-bin` package from the AUR inside a
throwaway Arch container. Brave is AUR-only, so the ISO itself never needs AUR
access. Built ISOs, `SHA256SUMS`, and a small manifest are written under
`axyl-out/<variant>/`.

The builder images are rebuilt on each run. `mkarchiso` runs privileged inside
Docker to create the loop-mounted ISO.

### Flash to USB

```bash
sudo ./flash.sh
# or choose an ISO explicitly:
sudo ./flash.sh axyl-out/arch/axyl-arch-*.iso
```

`flash.sh` lists **USB devices only**, excludes the live/root disk, verifies the
`.sha256` file when present, and requires you to type `FLASH` before writing.
Internal disks are never offered.

### Test in QEMU

```bash
# BIOS
qemu-system-x86_64 -cdrom axyl-out/arch/axyl-arch-*.iso -m 2G -boot d

# UEFI (requires edk2-ovmf)
qemu-system-x86_64 -cdrom axyl-out/arch/axyl-arch-*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

Hyprland needs a DRM/EGL-capable virtual GPU. For a graphical QEMU test use
`-vga virtio` (and an OpenGL display such as `-display gtk,gl=on`), rather than
plain VGA.

---

## Install

The installer is a real full-disk ext4 installer for UEFI and BIOS:

```bash
# Interactive: lists internal disks, asks for a password, requires ERASE.
sudo axyl-install

# Unattended (erases /dev/sda):
sudo axyl-install --auto --disk /dev/sda --yes --password 'choose-a-password'
```

Options: `--user`, `--hostname`, `--timezone`, `--allow-usb`. USB targets are
refused by default. The live/root disk is always refused. The target disk is
partitioned GPT: a 512 MiB EFI partition (UEFI) or 1 MiB BIOS boot partition,
plus the rest as ext4.

The installer:

- installs the variant's package manifest from `/usr/local/share/axyl/`;
- copies the live `/etc/skel` (Hyprland, Waybar, Mako, Kitty, Rofi, Neovim,
  Dolphin/KDE, theme engine, Brave wrapper) to the target;
- installs the vendored Brave package;
- creates the user, sets the password, locks root, enables `wheel` sudo;
- enables NetworkManager, Bluetooth, acpid, and greetd;
- regenerates the user's theme files for the real home directory;
- installs and configures GRUB for the detected firmware;
- writes a greeter-based `/etc/greetd/config.toml` (no live autologin).

Artix's package manifest uses Artix `system/world/galaxy`; only
`mkinitcpio-archiso` and `arch-install-scripts` come from Arch `[extra]` during
the live build.

---

## Desktop

- **Compositor/session**: Hyprland (Lua config), Wayland with XWayland fallback
- **Bar**: Waybar
- **Notifications**: Mako
- **Launcher**: Rofi
- **Terminal**: Kitty
- **Browser**: Brave (`brave-wayland` Ozone wrapper)
- **File manager**: Dolphin (KDE/KIO, Kvantum + qt6ct theming)
- **Editor**: Neovim with a vendored `lazy.nvim` plugin tree and offline
  Treesitter parsers
- **Shell**: zsh + Starship, autosuggestions, syntax highlighting
- **Audio**: PipeWire/WirePlumber, `wpctl`, pavucontrol
- **Bluetooth**: bluez + a small default-sink helper
- **Theme engine**: `~/.config/theme/render.py` renders Hyprland, Waybar,
  Mako/Rofi, Kitty, Starship, Neovim, Cava, KDE, Qt6ct, and GTK. Change
  `~/.config/theme/palette.json` and rerun it.
- **Lock/idle**: hyprlock + hypridle
- **Screenshots**: hyprshot
- **Clipboard**: cliphist + wl-clipboard

### Main keybindings

All bindings use **Super**.

| Binding | Action |
|---|---|
| `Super + Return` | Terminal |
| `Super + D` | App launcher |
| `Super + W` | Brave |
| `Super + E` | Dolphin |
| `Super + Shift + Q` | Power menu |
| `Super + Shift + R` | Reload Hyprland |
| `Super + /` | Keybind cheat sheet |
| `Super + Shift + T` | Theme picker |
| `Super + X` | Clipboard history |
| `Super + Shift + X` | Emoji picker (Arch; Artix lacks `rofi-emoji`) |
| `Super + 1..9` | Workspaces |
| `Super + Shift + 1..9` | Move window to workspace |
| `Super + R` | Enter resize mode |
| `Print` | Region screenshot |

`Super + Shift + Q` uses `hyprlock`, `loginctl` power actions, and the Rofi power
menu installed in `~/.config/rofi/powermenu.sh`.

---

## Live session

| Account | Password |
|---|---|
| `axyl` | `axyl` |
| `root` | `toor` |

`axyl` has passwordless sudo **in the live session only**. The installed system
does not keep that rule. Live autologin is implemented with greetd
`initial_session`; the installer writes a greeter-only config for the target.

The live timezone is `Asia/Manila`, hostname is `axyl`.

---

## Repository layout

```
archiso/        Arch profile: packages, profiledef, airootfs
artixiso/       Artix overlay/profile
skel/           shared /etc/skel (desktop, shell, nvim, theme)
docker/         builder Dockerfiles (arch, artix, brave)
build.sh        per-variant ISO build, checksums, manifest
flash.sh        USB-only flasher with checksum verification
```

`skel/` is injected into `/etc/skel` at build time. Personal host data
(`~/.ssh`, browser profiles, histories, caches, secrets, host-specific testing
repos) is intentionally not copied.
