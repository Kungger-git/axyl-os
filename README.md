# Axyl Linux

Axyl is a custom Linux live/install ISO built with `archiso`. It boots into a
pre-configured **Hyprland / Wayland** desktop using the opencode dark palette
(`#0a0a0a` background, `#fab283` accent). The live session starts as user
`axyl`; the installer creates a normal account with a real password and a
greeter on the installed system.

Two variants are available:

| Variant | Init system | UEFI bootloader | Output |
|---|---|---|---|
| `arch` | systemd | GRUB | `axyl-out/arch/axyl-arch-*.iso` |
| `artix` | runit | GRUB | `axyl-out/artix/axyl-artix-*.iso` |

Both variants identify as **Axyl Linux** in `/etc/os-release` and
`/usr/lib/os-release`; the underlying base remains visible through `ID=arch`
or `ID=artix`.

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

Additional checks on the installed target:

```bash
# One Waybar pill per pack; a single-battery VM shows only the internal pill.
~/.local/bin/waybar-battery BAT0
~/.local/bin/battery-guard --status

# Services menu (Super+Shift+M) lists only installed services.
~/.config/rofi/services.sh --list

# Time sync (systemd-timesyncd on Arch, chrony on Artix).
timedatectl status        # Artix: chronyc tracking

# Early microcode hook is present.
grep '^HOOKS=' /etc/mkinitcpio.conf
```

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

- installs the variant's package manifest from `/usr/local/share/axyl/`
  (includes `pipewire-audio`, `iw`, and `wireless-regdb`);
- copies the live `/etc/skel` (Hyprland, Waybar, Mako, Foot, Rofi, Neovim,
  Dolphin/KDE, theme engine, Brave wrapper) to the target;
- installs the vendored Brave package;
- creates the user, sets the password, locks root, enables `wheel` sudo;
- enables NetworkManager, Bluetooth, greetd, Early OOM, and a fallback tty2
  console; `fwupd-refresh.timer` is enabled on Arch, while Artix uses manual
  `fwupdmgr` runs because fwupd there is D-Bus-activated;
- enables `systemd-timesyncd` on Arch and `chrony` under runit on Artix; both
  live and installed systems sync time. `upower` is not explicitly listed or
  enabled; Waybar pulls it in as a dependency, but the battery helpers read
  sysfs directly;
- adds the `microcode` initramfs hook for `intel-ucode`/`amd-ucode`;
- drops `resolve` from `nsswitch.conf` (systemd-resolved is not installed) and
  hardens the vfat ESP with `fmask=0077,dmask=0077`;
- writes zram swap (half of RAM, capped at 4 GiB, zstd) plus
  `vm.swappiness=100`/`vm.page-cluster=0`, and hardware-neutral TLP defaults;
- mounts the root filesystem `noatime`, boots with `zswap.enabled=0` (no double
  compression next to zram), and enables weekly TRIM — `fstrim.timer` on Arch,
  the `axyl-tune` runit service on Artix;
- boots the installed system with a 2 s GRUB menu;
- regenerates the user's theme files for the real home directory;
- installs and configures GRUB for the detected firmware;
- writes a greeter-based `/etc/greetd/config.toml` (no live autologin).

Artix's package manifest uses Artix `system/world/galaxy`; only
`mkinitcpio-archiso` and `arch-install-scripts` come from Arch `[extra]` during
the live build.

---

## Desktop

- **Compositor/session**: Hyprland (Lua config), Wayland with XWayland fallback
- **Bar**: Waybar (the `A` on the left opens and closes the launcher)
- **Notifications**: Mako
- **Launcher**: Rofi
- **Terminal**: Foot (Kitty stays installed as a fallback)
- **Browser**: Brave (`brave-wayland` Ozone wrapper)
- **File manager**: Dolphin (KDE/KIO, Kvantum + qt6ct theming)
- **Editor**: Neovim with a vendored `lazy.nvim` plugin tree and offline
  Treesitter parsers
- **Shell**: zsh + Starship, autosuggestions, syntax highlighting
- **Audio**: PipeWire/WirePlumber, `wpctl`, pavucontrol
- **Bluetooth**: bluez + a small default-sink helper
- **Batteries**: `waybar-battery` renders one Waybar pill per pack (BAT0/BAT1)
  and hides packs that are absent; `battery-guard` sends low-charge and
  charge-limit notifications from sysfs
- **Services menu**: Rofi toggles Bluetooth, Early OOM, Wi-Fi adapters, and
  installed services; uses `systemctl` on Arch and `sv` on Artix. It also offers a
  "Network wait-online" boot toggle and a "Hyprland effects" switch that turns
  blur, shadows, and animations off at runtime.
- **Theme engine**: `~/.config/theme/render.py` renders Hyprland, Waybar,
  Mako/Rofi, Foot/Kitty, Starship, Neovim, Cava, KDE, Qt6ct, and GTK. Colours
  and layout both come from `~/.config/theme/palette.json`; the four shipped
  designs live in `~/.config/theme/designs.json`.

### Designs

Four complete looks ship in the image. Each one sets the palette **and** the
layout — bar style and position, rounding, gaps, borders, blur and shadows —
so switching changes the whole feel of the desktop, not just the colours.

| Design | Bar | Rounding | Blur | Matches |
|---|---|---|---|---|
| `ember` | floating islands, top | 12 px | on | opencode (default) |
| `glacier` | flat full-width, top | 4 px | off | nord |
| `amber` | chunky slab, top | 8 px | off | gruvbox |
| `violet` | glass dock, bottom | 14 px | on | synthwave84 |

```bash
~/.config/theme/themes.py list             # designs first, then opencode themes
~/.config/theme/themes.py set glacier      # palette + layout
~/.config/theme/themes.py set tokyonight   # colours only, layout kept
~/.config/theme/themes.py pick             # rofi picker (SUPER + SHIFT + T)
```

Designs also pick the opencode TUI theme shown in the table. `glacier` and
`amber` turn blur off, which is the cheapest option on low-end GPUs;
`violet` moves the bar to the bottom and is the heaviest.
- **Lock/idle**: hyprlock + hypridle
- **Screenshots**: `~/.local/bin/screenshot` (grim + slurp, saves to
  `~/Pictures/Screenshots` and copies to the clipboard)
- **Clipboard**: cliphist + wl-clipboard

### Performance defaults

The image targets low-spec hardware: zram instead of disk swap, TLP power
management, Early OOM, the `schedutil` governor, `noatime`, periodic TRIM,
per-design Hyprland blur (off in `glacier` and `amber`), and Waybar polling no
faster than 5 s. Live menus boot
automatically after 3 s (Arch) or 5 s (Artix), and installed systems use a 2 s
GRUB menu. `~/.local/bin/hypr-effects performance` (or the Services menu) turns
blur, shadows, and animations off for the current session; `hyprctl reload`
restores the configured look.

### Gaming, firmware, and microphones

`axyl-game` wraps a game with GameMode and MangoHud in the current Hyprland
session:

```bash
axyl-game /path/to/game
axyl-game --gamescope /path/to/game    # nested 1920x1080@60 gamescope window
axyl-game --no-mangohud /path/to/game
```

`AXYL_GAME_WIDTH`, `AXYL_GAME_HEIGHT`, and `AXYL_GAME_REFRESH` change the
gamescope output size. MangoHud uses `~/.config/MangoHud/MangoHud.conf`; press
`Shift+F12` to toggle it. This is a per-game wrapper only: log in normally to
Hyprland and launch games through it, rather than booting a separate Gamescope
session.

Firmware updates are manual with `sudo fwupdmgr get-updates` and
`sudo fwupdmgr update`. Arch enables `fwupd-refresh.timer`; on Artix fwupd is
D-Bus-activated with no runit service, so run `fwupdmgr refresh` yourself.
Flatpak is installed for sandboxed applications (`flatpak remote-add --if-not-exists
flathub https://flathub.org/repo/flathub.flatpakrepo`).

PipeWire's echo canceller loads from
`~/.config/pipewire/pipewire.conf.d/99-axyl-echo-cancel.conf`. Pick
**Axyl Echo-Cancelled Microphone** in the app's input device list for speaker
echo suppression; when no speakers are active it falls back to the normal
microphone.

The image intentionally ships no 32-bit/multilib gaming stack. Steam and
other 32-bit titles need the `multilib` repository enabled and a
`[multilib]`-aware package list, which this ISO does not configure.

### Main keybindings

All bindings use **Super**.

| Binding | Action |
|---|---|
| `Super + Return` | Terminal |
| `Super + D` | App launcher |
| `Super + W` | Brave |
| `Super + E` | Dolphin |
| `Super + Shift + Q` | Power menu |
| `Super + Shift + M` | Services menu (Bluetooth, Wi-Fi, Docker, VPN, effects) |
| `Super + Shift + R` | Reload Hyprland |
| `Super + /` | Keybind cheat sheet |
| `Super + Shift + T` | Theme picker |
| `Super + X` | Clipboard history |
| `Super + 1..9` | Workspaces |
| `Super + Shift + 1..9` | Move window to workspace |
| `Super + R` | Enter resize mode |
| `Print` | Region screenshot |

`Super + Shift + Q` uses `hyprlock`, `loginctl` power actions, and the Rofi power
menu installed in `~/.config/rofi/powermenu.sh`. `loginctl` works with both
systemd and elogind, so the same menu runs on Arch and Artix.

---

## Live session

| Account | Password |
|---|---|
| `axyl` | `axyl` |
| `root` | `toor` |

`axyl` has passwordless sudo **in the live session only**. The installed system
does not keep that rule. Live autologin is implemented with greetd
`initial_session`; the installer writes a greeter-only config for the target.

The live timezone is `Asia/Manila`, hostname is `axyl`. The live desktop also
syncs time automatically (`systemd-timesyncd` on Arch, `chrony` on Artix).

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
