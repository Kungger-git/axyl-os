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

Hyprland needs a DRM/EGL-capable virtual GPU. Use `virtio-vga-gl` with an
OpenGL display when available; otherwise use `-vga virtio` and a GL-capable
display.

The examples below use a disposable qcow2 disk. Never point `--disk` at a host
disk: inside QEMU the test disk is `/dev/vda`.

```bash
ISO=axyl-out/arch/axyl-arch-*.iso   # or axyl-out/artix/axyl-artix-*.iso
DISK="$HOME/axyl-test.qcow2"
qemu-img create -f qcow2 "$DISK" 20G
```

Boot the live ISO in BIOS mode:

```bash
qemu-system-x86_64 \
  -machine q35 -enable-kvm -cpu host -smp 2 -m 2048 \
  -device virtio-vga-gl -vga none -display gtk,gl=on \
  -nic user,model=virtio-net-pci \
  -boot order=d,menu=off \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -cdrom "$ISO"
```

UEFI live boot (requires `edk2-ovmf`):

```bash
cp /usr/share/ovmf/x64/OVMF_VARS.4m.fd /tmp/axyl-OVMF_VARS.fd

qemu-system-x86_64 \
  -machine q35 -enable-kvm -cpu host -smp 2 -m 2048 \
  -device virtio-vga-gl -vga none -display gtk,gl=on \
  -nic user,model=virtio-net-pci \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/ovmf/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/axyl-OVMF_VARS.fd \
  -boot order=d,menu=off \
  -cdrom "$ISO"
```

The live session autologs in as `axyl` (password `axyl`; `root` is `toor`).
Check the live desktop:

```bash
pactl info
command -v brave dolphin nvim
```

Install to the disposable disk from inside the live session:

```bash
sudo axyl-install --auto --disk /dev/vda --yes --password axyl
```

The installer must finish with `ok Installation complete.` If it reports that
the target is still mounted and a lazy unmount was requested, shut down the VM
and boot the installed disk once before using it.

Boot the installed system without the ISO attached:

```bash
qemu-system-x86_64 \
  -machine q35 -enable-kvm -cpu host -smp 2 -m 2048 \
  -device virtio-vga-gl -vga none -display gtk,gl=on \
  -nic user,model=virtio-net-pci \
  -boot order=c,menu=off \
  -drive file="$DISK",if=virtio,format=qcow2
```

For a UEFI install, keep the two `-drive if=pflash` options from the UEFI live
command and boot the installed disk with `-boot order=c`.

The installed system starts greetd on tty7. Log in as `axyl` with the password
passed to the installer, then verify Hyprland, Waybar, audio, Brave, Dolphin,
and Neovim. `Ctrl+Alt+F2` should show a separate text login.

Test both `arch` and `artix` ISOs. Audio startup is systemd-user based on Arch
and uses the manual PipeWire branch on Artix; in both cases `pactl info` should
report `/run/user/1000/pulse/native`.

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
