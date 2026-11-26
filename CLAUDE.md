# CLAUDE.md — Axyl Linux ISO (Arch + Artix, Hyprland)

This file is the authoritative reference for all future Claude sessions in this repository. Follow every rule here precisely and consistently.

---

## Project Overview

**Axyl Linux** is a custom Linux live/install ISO built with `archiso`. It boots straight into a **Hyprland / Wayland** desktop themed with the opencode dark palette (`#0a0a0a` background, `#fab283` accent), with greetd autologin, Waybar, Mako, Rofi, Foot, and an interactive full-disk installer.

There is **no bspwm, X11 session, polybar, sxhkd, picom, or dunst** in this tree. Anything describing those is stale by definition.

| Variant | Init system | Live BIOS | Live UEFI | Installed bootloader |
|---|---|---|---|---|
| `arch` | systemd | syslinux | systemd-boot | GRUB |
| `artix` | runit | syslinux | GRUB | GRUB |

**Build command:** `./build.sh [arch|artix]` — defaults to `arch`.

**Editing environment:** Windows (VS Code / OneDrive). **Build environment:** any Linux host with Docker. Both variants build inside Docker; no native Arch or Artix host is required.

---

## Repository Layout

`build.sh` assembles a temporary profile directory per variant, then runs `mkarchiso` inside a container:

1. Copy `archiso/` (base for both variants)
2. For artix only: overlay `artixiso/` on top (`cp -rT` — files in `artixiso/` win on collision)
3. Copy `skel/` into `tmp/airootfs/etc/skel/` (shared; variant-neutral)
4. Copy the vendored `brave-bin` package into `tmp/airootfs/usr/local/share/axyl/`

`skel/` lives at the repo root so it is clearly owned by neither variant.

```
archiso/                              ← base profile for both variants
  profiledef.sh                       ← ISO metadata, bootmodes, compression, file_permissions
  packages.x86_64                     ← every package installed in the Arch live system
  pacman.conf                         ← profile pacman config (ParallelDownloads=1)
  airootfs/                           ← overlay copied verbatim into the live rootfs
    etc/
      axyl/variant                    ← "arch"  (artix overlay writes "artix")
      greetd/config.toml              ← live autologin via [initial_session], VT7
      issue, locale.conf, vconsole.conf, os-release
      mkinitcpio.conf
      pacman.conf, pacman.d/mirrorlist
      pacman.d/hooks/99-axyl-os-release.hook   ← keeps /usr/lib/os-release branded
      sysctl.d/99-zram.conf, systemd/zram-generator.conf, tlp.d/50-axyl.conf
    root/
      customize_airootfs.sh           ← chroot hook: runs after packages installed
    usr/local/bin/
      start-hyprland-session          ← Wayland session entry point (greetd)
      brave-wayland                   ← Brave with Ozone/Wayland flags
      axyl-install                    ← full-disk installer (both variants)
      axyl-setup                      ← post-install repair helper
      axyl-game                       ← GameMode + MangoHud (+ gamescope) wrapper
    usr/local/share/axyl/
      packages.target                 ← package list the installer pacstraps
      brave-bin-*.pkg.tar.zst         ← injected by build.sh (not committed)
  efiboot/loader/                     ← systemd-boot (live Arch UEFI)
  syslinux/syslinux.cfg               ← live BIOS menu (both variants)

artixiso/                             ← override layer: files here win over archiso/
  profiledef.sh                       ← Artix overrides (labels, uefi-x64.grub.esp)
  packages.x86_64                     ← Artix package list (runit packages, zramen, chrony)
  pacman.conf                         ← system/world/galaxy + Arch [extra]
  grub/grub.cfg                       ← live GRUB UEFI menu
  airootfs/
    etc/axyl/variant                  ← "artix"
    etc/greetd/config.toml            ← live autologin (identical to archiso)
    etc/mkinitcpio.conf               ← MODULES includes isofs
    etc/pacman.conf, pacman.d/mirrorlist
    etc/runit/sv/axyl-tune/run        ← sysctl + weekly fstrim, never exits
    etc/runit/sv/tlp/{run,finish}     ← TLP under runsv
    etc/runit/sv/zramen/conf          ← zramen tunables
    root/customize_airootfs.sh        ← runit services, initramfs rebuild
    usr/bin/{pacstrap,arch-chroot,genfstab}          ← arch-install-scripts payload
    usr/lib/initcpio/{hooks,install}/archiso*        ← mkinitcpio-archiso payload
    usr/local/bin/{axyl-install,axyl-setup,brave-wayland,start-hyprland-session}
    usr/local/share/axyl/packages.target

skel/                                 ← shared /etc/skel, injected by build.sh into both variants
  .bash_profile, .bashrc, .zshrc, .gtkrc-2.0
  .local/bin/
    screenshot                        ← grim + slurp, saves + copies to clipboard
    start-audio.sh                    ← PipeWire bootstrap (systemd or manual)
    bt-default-sink.sh                ← keeps a bluez sink as default (manual helper)
    waybar-battery                    ← JSON battery module for Waybar (BAT0/BAT1)
    battery-guard                     ← low-charge / charge-limit notifications (manual helper)
    hypr-effects                      ← runtime blur/shadow/animation switch
    timer                             ← themed ASCII countdown timer
  .config/
    hypr/hyprland.lua                 ← entry point; requires conf/*.lua
    hypr/conf/{variables,palette,design,appearance,env,input,misc,autostart,keybinds,rules,monitors}.lua
    hypr/hypridle.conf, hypr/hyprlock.conf        (hyprlock.conf is generated)
    waybar/{config,style.css}                     (both generated)
    mako/config                                   (generated)
    rofi/{config.rasi,style.rasi,powermenu.rasi}  (style/powermenu generated)
    rofi/{powermenu.sh,services.sh,keybinds.sh}
    foot/{foot.ini,colors.ini}                    (colors.ini generated)
    kitty/{kitty.conf,colors.conf}                (colors.conf generated)
    theme/palette.json                ← SOURCE OF TRUTH for colours + layout
    theme/palette.prev.json           ← previous theme (written by themes.py set)
    theme/designs.json                ← the four Axyl designs (palette + layout)
    theme/render.py                   ← palette.json → every app config
    theme/themes.py                   ← switch designs / opencode themes / picker / sync
    theme/opencode-themes/*.json      ← vendored opencode theme assets
    nvim/{init.lua,lazy-bootstrap.lua,lazy-lock.json,colors/opencode.lua}
    KDE/Qt: kdeglobals (generated), dolphinrc, kiorc, baloofileinformationrc,
            filetypesrc, mimeapps.list, qt5ct/, qt6ct/, Kvantum/
    gtk-3.0/, gtk-4.0/                (settings.ini + gtk.css generated)
    starship.toml (generated), cava/config (generated block)
    fastfetch/{config.jsonc,axyl.txt}, zathura/zathurarc, ranger/,
    MangoHud/MangoHud.conf, pipewire/pipewire.conf.d/99-axyl-echo-cancel.conf,
    ascii-timer/config, environment.d/qt-theme.conf
  .local/share/nvim/lazy/                         ← vendored plugin tree (do not prune casually)
  .local/share/color-schemes/opencode.colors      (generated)

docker/
  Dockerfile.arch                     ← build-host packages for the arch variant
  Dockerfile.artix                    ← build-host packages for the artix variant
  Dockerfile.brave                    ← builds the vendored brave-bin package
build.sh                              ← assembles profile, builds image, runs mkarchiso
flash.sh                              ← USB-only ISO writer with checksum verification
setup.sh                              ← host prep (Docker, optional QEMU)
test.sh                               ← QEMU harness (BIOS/UEFI, disk, QMP, headless)
tools/qmp.py                          ← QMP helper copied to ~/axyl-qemu for headless tests
```

---

## Build System

### Build pipeline (`build.sh`)

1. `mktemp -d /tmp/axyl-<variant>-XXXXX`, `cp -rT archiso/` (plus `artixiso/` for artix).
2. `cp -rT skel/ → airootfs/etc/skel` — this happens **before** `useradd -m`, so the live user's home is fully populated.
3. Build `brave-bin` once into `axyl-build/pkgs/` (gitignored) using `docker/Dockerfile.brave`, then copy it into `airootfs/usr/local/share/axyl/`.
4. `docker rmi` the builder image if present, then `docker build --pull --no-cache` from `docker/Dockerfile.<variant>`. Nothing is cached.
5. Clear `axyl-out/<variant>/` of old ISOs/checksums, then run `mkarchiso -v -w /tmp/axyl-work -o /out /profile` with `--privileged` (loop mounts).
6. Write `<iso>.sha256` and `axyl-<variant>-manifest.txt` (`variant`, `version`, `iso`, `sha256`, `built_utc`, `profile`).

Output paths: `axyl-out/arch/axyl-arch-<Y.m.d>-x86_64.iso`, `axyl-out/artix/axyl-artix-<Y.m.d>-x86_64.iso`.

### profiledef.sh — current values

**Arch** (`archiso/profiledef.sh`):

```bash
iso_name="axyl-arch"
iso_label="AXYL_ARCH_$(date +%y.%m)"
iso_application="Axyl Linux Live/Install CD (Arch-based / systemd)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '512K')
```

**Artix** (`artixiso/profiledef.sh`): identical except

```bash
iso_name="axyl-artix"
iso_label="AXYL_ARTIX_$(date +%y.%m)"
iso_application="Axyl Linux Live/Install CD (Artix-based / runit)"
bootmodes=('bios.syslinux' 'uefi-x64.grub.esp')
```

Note the label uses a two-digit year (`%y.%m`), and `install_dir` stays `"arch"` on **both** variants — the ISO payload path is `/arch/...` even for `axyl-artix`.

### file_permissions

`file_permissions` is applied by mkarchiso before the chroot runs; paths are live-rootfs paths. **It must be a plain assignment, not `declare -A`:** mkarchiso sources `profiledef.sh` inside a function, where `declare` would create a local array and leave mkarchiso's global `file_permissions` empty — every overlay file would stay `0644`.

Arch list (`archiso/profiledef.sh`):

```bash
file_permissions=(
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/usr/local/bin/start-hyprland-session"]="0:0:755"
    ["/usr/local/bin/brave-wayland"]="0:0:755"
    ["/usr/local/bin/axyl-install"]="0:0:755"
    ["/usr/local/bin/axyl-setup"]="0:0:755"
    ["/usr/local/bin/axyl-game"]="0:0:755"
    ["/etc/skel/.local/bin/bt-default-sink.sh"]="0:0:755"
    ["/etc/skel/.local/bin/waybar-battery"]="0:0:755"
    ["/etc/skel/.local/bin/battery-guard"]="0:0:755"
    ["/etc/skel/.local/bin/start-audio.sh"]="0:0:755"
    ["/etc/skel/.local/bin/timer"]="0:0:755"
    ["/etc/skel/.local/bin/screenshot"]="0:0:755"
    ["/etc/skel/.local/bin/hypr-effects"]="0:0:755"
    ["/etc/skel/.config/rofi/powermenu.sh"]="0:0:755"
    ["/etc/skel/.config/rofi/services.sh"]="0:0:755"
    ["/etc/skel/.config/rofi/keybinds.sh"]="0:0:755"
    ["/etc/skel/.config/theme/render.py"]="0:0:755"
    ["/etc/skel/.config/theme/themes.py"]="0:0:755"
)
```

Artix adds the overlay-only entries: `/usr/bin/{pacstrap,arch-chroot,genfstab}`, `/usr/lib/initcpio/{hooks,install}/archiso*`, and `/etc/runit/sv/{axyl-tune,tlp}/{run,finish}`.

`customize_airootfs.sh` repeats the `chmod 0755` for the same paths (skel **and** `/home/axyl`) as a safety net, because `useradd -m` does not reliably preserve execute bits.

### mkinitcpio.conf

**Arch:** `MODULES=(loop squashfs overlay)`, `HOOKS=(base udev modconf archiso archiso_loop_mnt kms block filesystems keyboard)`, `COMPRESSION="xz"`.

**Artix:** identical except `MODULES=(loop squashfs overlay isofs)`.

**Why `isofs` is required for Artix:** the Arch `mkinitcpio-archiso` install hook adds `isofs` internally. On Artix the hook set is shipped in this overlay and the live system uses Artix's `mkinitcpio` from `[world]`; without `isofs` in the initramfs the `archiso` hook finds the CD-ROM by label but cannot mount ISO 9660 — kernel panic `VFS: Unable to mount root fs on unknown-block(0,0)`.

**Hook rules (non-negotiable):**

- `archiso` and `archiso_loop_mnt` come from **`mkinitcpio-archiso`**, not from `archiso`.
- `archiso_shutdown` was removed from `mkinitcpio-archiso`. Never add it.
- `archiso_kms` is deprecated. Use the standard `kms` hook.
- `archiso` and `archiso_loop_mnt` must appear before `block`.
- The file is a direct `/etc/mkinitcpio.conf` (not a drop-in) and takes precedence over anything in `mkinitcpio.conf.d/`.

### Bootloaders

**Live BIOS — syslinux** (`archiso/syslinux/syslinux.cfg`, used by both variants; `TIMEOUT 30` = 3 s):

```
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=1G zswap.enabled=0
```

Entries: normal, `nomodeset`, reboot, poweroff.

**Live Arch UEFI — systemd-boot** (`archiso/efiboot/loader/`): same cmdline, timeout 3, `editor no`. Initrds reference `/%INSTALL_DIR%/boot/intel-ucode.img`, `.../amd-ucode.img`, and `/%INSTALL_DIR%/boot/x86_64/initramfs-linux.img`. systemd-boot needs **no grub package on the build host**.

**Live Artix UEFI — GRUB** (`artixiso/grub/grub.cfg`): `uefi-x64.grub.esp` calls `grub-mkstandalone` on the build host, so `grub` MUST be in `docker/Dockerfile.artix`. Timeout 5.

**Installed systems always use GRUB** (UEFI `--target=x86_64-efi --efi-directory=/boot --bootloader-id=Axyl`, BIOS `--target=i386-pc`) with a 2 s menu and `quiet zswap.enabled=0`. Do not "fix" the live Arch UEFI bootmode to match the installed system.

### customize_airootfs.sh — execution order

Runs in a chroot of the live rootfs after packages are installed. **Order matters.**

Arch (`archiso/airootfs/root/customize_airootfs.sh`):

1. `pacman-key --init && pacman-key --populate archlinux` — MUST be first
2. Locale (`en_US.UTF-8`), timezone `Asia/Manila`, hostname `axyl`, `/etc/hosts`
3. Branding: `install -Dm644 /etc/os-release /usr/lib/os-release`
4. `systemctl enable`: NetworkManager, greetd, getty@tty2, bluetooth, systemd-timesyncd, tlp, fstrim.timer, earlyoom, fwupd-refresh.timer; `disable NetworkManager-wait-online`; `set-default graphical.target`
5. Create the `greeter` group/user and `/var/lib/greetd` if the package did not
6. `groupadd -f` for wheel/audio/video/render/input/storage/optical/network, then `useradd -m -G ... -s /bin/zsh axyl` (copies `/etc/skel`, including the vendored nvim tree)
7. Passwords (`axyl`/`axyl`, `root`/`toor`), passwordless sudo for `axyl`, `xdg-user-dirs-update`, `~/Pictures/Screenshots`
8. Install the vendored `brave-bin` package, retrying with `CheckSpace` disabled on failure
9. `chmod 0755` safety net (skel + `/home/axyl`)
10. Run `~/.config/theme/render.py` as `axyl` so generated files belong to the user
11. `fc-cache -fv` for root and `axyl`
12. `pacman -Scc --noconfirm`

Artix inserts the initramfs rebuild after branding (step 3) and replaces step 4 with runit symlinks:

```bash
for svc in dbus NetworkManager greetd bluetoothd agetty-tty2 chrony tlp zramen axyl-tune earlyoom; do
    [ -d "/etc/runit/sv/$svc" ] && ln -sf "/etc/runit/sv/$svc" /etc/runit/runsvdir/default/
done
```

`elogind-runit` already enables `logind` (an alias for the same service) — never add `elogind` as well, or two supervisors run one daemon. Only `agetty-tty2` stays enabled: greetd owns VT7 and tty2 is the documented fallback console.

### greetd and the session chain

Live config (`archiso/airootfs/etc/greetd/config.toml`, copied verbatim into `artixiso/`), VT7:

```toml
[default_session]
command = "agreety --cmd /usr/local/bin/start-hyprland-session"
user = "greeter"

[initial_session]
command = "/usr/local/bin/start-hyprland-session"
user = "axyl"
```

`[initial_session]` **is** the autologin mechanism. `[default_session]` is only the fallback greeter shown after the session ends. The installer and `axyl-setup` rewrite this file **without** `[initial_session]` for installed systems.

```
greetd (PAM session for axyl, VT7)
  └─ /usr/local/bin/start-hyprland-session
       ├─ XDG_RUNTIME_DIR: reuse /run/user/<uid>, else private mktemp dir
       ├─ XDG_SESSION_TYPE=wayland, XDG_SESSION_DESKTOP/XDG_CURRENT_DESKTOP=Hyprland
       ├─ QT_QPA_PLATFORM="wayland;xcb", QT_QPA_PLATFORMTHEME=qt6ct,
       │  QT_STYLE_OVERRIDE=kvantum, MOZ_ENABLE_WAYLAND=1,
       │  ELECTRON_OZONE_PLATFORM_HINT=auto
       ├─ VM detection (qemu/kvm/virtualbox/vmware): WLR_NO_HARDWARE_CURSORS=1 and,
       │  only when /dev/dri/renderD128 is absent, WLR_RENDERER=pixman
       ├─ runs ~/.config/theme/render.py (regenerates every themed file)
       └─ exec dbus-run-session start-hyprland
            └─ hyprland.lua requires conf/{monitors,env,autostart,appearance,input,misc,keybinds,rules}
                 └─ autostart on "hyprland.start":
                      start-audio.sh, waybar, mako, hypridle,
                      wl-paste --watch cliphist store,
                      /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

`start-hyprland-session` is **not** an X session: there is no `startx`, no `.xinitrc`, no `xset`/`xsetroot`.

---

## Desktop Architecture

### Hyprland configuration (Lua)

Hyprland **≥ 0.55** is required: if `~/.config/hypr/hyprland.lua` exists it is loaded instead of `hyprland.conf`. Editing a `.conf` file has no effect.

- `hyprland.lua` is only a list of `require()` calls. Each module runs in its own scope, so a syntax error in one does not stop the others.
- Shared values (terminal, file manager, launcher, modifier) live in `conf/variables.lua`, which returns a table.
- Colours come from `conf/palette.lua`, which is **generated** — never edit it.
- Keybinds in `conf/keybinds.lua` all carry a `description`, because `rofi/keybinds.sh` builds the cheat sheet from `hyprctl binds -j`.
- `hyprctl keyword` does not work with a Lua config on 0.5x; use `hyprctl eval "hl.config({...})"`. `hypr-effects` tries `eval` first and falls back to keywords for older releases.

### Theme engine

`~/.config/theme/palette.json` is the single source of truth for every colour **and** for layout. It carries a `layout` block (`bar_style`, `bar_position`, `bar_height`, `bar_margin`, `bar_radius`, `rounding`, `gaps_in/out`, `border_size`, shadow/blur settings, `rofi_radius`, `rofi_width`). `render.py` fills templates with those tokens and writes:

```
hypr/conf/palette.lua         hypr/conf/design.lua
hypr/hyprlock.conf            kitty/colors.conf
foot/colors.ini               mako/config
fastfetch/config.jsonc        waybar/config
waybar/style.css              rofi/style.rasi
rofi/powermenu.rasi           starship.toml
nvim/colors/opencode.lua      cava/config (managed [color] block)
kdeglobals                    .local/share/color-schemes/opencode.colors
qt6ct/colors/opencode.conf    gtk-3.0/{settings.ini,gtk.css}
gtk-4.0/{settings.ini,gtk.css}
```

Every generated file carries a `GENERATED by ~/.config/theme/render.py -- do not edit by hand` header. To change the look, edit `palette.json` (or the templates inside `render.py`) and run:

```bash
~/.config/theme/render.py            # regenerate
~/.config/theme/render.py --reload   # regenerate + hyprctl reload, kitty USR1, waybar SIGUSR2
```

`themes.py` switches between the four Axyl designs defined in `designs.json` and the vendored opencode themes:

```bash
~/.config/theme/themes.py list       # designs + themes, current marked
~/.config/theme/themes.py current
~/.config/theme/themes.py set <name> # design or opencode theme
~/.config/theme/themes.py pick       # rofi picker (SUPER + SHIFT + T)
~/.config/theme/themes.py preview <name>  # apply without persisting (picker hover)
~/.config/theme/themes.py sync       # re-vendor theme JSONs from GitHub for the installed opencode
```

The picker passes `-on-selection-changed` to rofi, so highlighting a row runs
`preview <name>`: the palette is applied and re-rendered immediately, and the
original bytes are written back when rofi exits without a choice. `preview`
never touches `palette.prev.json` or `opencode/cli.json`. An opencode theme
keeps the layout the picker started from (saved in
`~/.config/theme/.preview-base.json`), so hovering a bottom-dock design first
cannot drag the bar down for the themes after it.

| Design | Bar | Rounding | Blur | TUI theme |
|---|---|---|---|---|
| `ember` | floating islands, top | 12 | on | `opencode` |
| `glacier` | flat full-width, top | 4 | off | `nord` |
| `amber` | chunky slab, top | 8 | off | `gruvbox` |
| `violet` | glass dock, bottom | 14 | on | `synthwave84` |

A design sets palette **and** layout together. An opencode theme changes colours only and keeps the current layout. `set` keeps the previous palette in `palette.prev.json`, warns below 4.5:1 contrast, restores the old palette if rendering fails, and writes `theme = { name, mode = "dark" }` to `~/.config/opencode/cli.json` before calling `opencode reload`. `lucent-orng` is excluded because all its backgrounds are transparent.

### Desktop components

| Role | Component | Notes |
|---|---|---|
| Compositor | Hyprland (Lua config) | Wayland + XWayland fallback |
| Bar | Waybar | generated `config` (JSONC) + `style.css` from the layout block |
| Notifications | Mako | generated config |
| Launcher / menus | Rofi | `drun`, window switcher (`SUPER+A`), power, services, keybinds, emoji |
| Terminal | Foot | Kitty is installed as a fallback and themed too |
| Browser | Brave (`brave-bin`) | `brave-wayland` adds Ozone/Wayland flags |
| File manager | Dolphin (KDE/KIO) | Kvantum + qt6ct + `kdeglobals` |
| Editor | Neovim | vendored `lazy.nvim` tree + parsers; no network at startup |
| Shell | zsh + Starship | autosuggestions, syntax highlighting, completion |
| Audio | PipeWire / WirePlumber | `wpctl`, `pactl`, pavucontrol |
| Lock / idle | hyprlock + hypridle | autolock disabled; DPMS off after 330 s |
| Clipboard | cliphist + wl-clipboard | `wl-paste --watch cliphist store` in autostart |
| Screenshots | grim + slurp + jq | `~/.local/bin/screenshot` |
| Wallpaper | none | solid `misc.background_color`; Hyprland logo/mascot disabled |

Helpers that are **not** auto-started (run them manually or from a bind): `bt-default-sink.sh`, `battery-guard`. `waybar-battery` is invoked by Waybar every 10 s.

### Rofi scripts

- `rofi/powermenu.sh` — Lock (`hyprlock`), Logout (`hyprctl dispatch exit`), Reboot/Shutdown/Suspend via `loginctl`. Works on systemd and elogind.
- `rofi/services.sh` — toggles Bluetooth, Early OOM, Wi-Fi adapters, and installed services (Docker/SSH/Apache/Proton VPN); plus NetworkManager wait-online (systemd) and the Hyprland effects switch. Detects systemd vs runit at runtime (`/run/systemd/system`), uses `systemctl` or `sv` + `runsvdir` symlinks; root actions via passwordless sudo, else `pkexec`. `--list` prints the menu without opening rofi.
- `rofi/keybinds.sh` — reads `hyprctl binds -j` and renders the cheat sheet. `--list` prints text.

### Effects switch

`hypr-effects [status|full|performance|toggle]` switches `decoration:blur`, `decoration:shadow`, `animations` at runtime only; `hyprctl reload` or a re-login restores `conf/appearance.lua`.

---

## Colour Scheme

The shipped default is the `ember` design: opencode's dark palette with a softer border, a floating island bar, 12px rounding and 8/12px gaps. The other three designs (`glacier`, `amber`, `violet`) live in `theme/designs.json`. `palette.json` roles:

| Role | Hex | Used in |
|---|---|---|
| `bg` | `#0a0a0a` | Desktop background, bar, terminal |
| `bg_panel` | `#141414` | Panels, notifications, lock screen |
| `bg_elem` | `#1e1e1e` | Inputs, selected rows |
| `overlay` | `#4e4e4e` | Overlays, disabled text |
| `border` | `#2a2a2a` | Borders, separators |
| `scrollbar` | `#5a5a5a` | Scrollbars |
| `fg` | `#eeeeee` | Primary text |
| `fg_muted` | `#808080` | Secondary text, inactive |
| `accent` | `#fab283` | Focused border, prompt, active workspace |
| `secondary` | `#5c9cf5` | Links, info highlights |
| `accent_alt` | `#9d7cd8` | Preselection, hover |
| `red` / `green` / `yellow` / `orange` / `cyan` | `#e06c75` `#7fd88f` `#f8c17b` `#f5a742` `#56b6c2` | Urgent, success, warnings, highlights |

`bright.*` provides the lighter ramp used by terminals and Neovim.

The live desktop uses `SUPER + SHIFT + T` (theme picker) to switch themes; the choice persists in `palette.json` and `~/.config/opencode/cli.json`.

---

## Keybindings

All binds use **Super**. Source: `skel/.config/hypr/conf/keybinds.lua`.

| Binding | Action |
|---|---|
| `SUPER + Return` | Foot terminal |
| `SUPER + D` | Rofi app launcher |
| `SUPER + A` | Rofi window switcher |
| `SUPER + W` | Brave |
| `SUPER + E` | Dolphin |
| `SUPER + Q` | Close window |
| `SUPER + L` | Lock (hyprlock) |
| `SUPER + SHIFT + Q` | Power menu |
| `SUPER + SHIFT + M` | Services menu |
| `SUPER + SHIFT + E` | Exit Hyprland (`hyprshutdown` if present, else `hl.dsp.exit()`) |
| `SUPER + SHIFT + R` | Reload Hyprland config |
| `SUPER + SHIFT + B` | Reload Waybar |
| `SUPER + SHIFT + D` | Displays off (DPMS, 500 ms delay) |
| `SUPER + SHIFT + T` | Theme picker |
| `SUPER + /` | Keybind cheat sheet |
| `SUPER + X` | Clipboard history |
| `SUPER + SHIFT + X` | Emoji picker |
| `SUPER + C` | Colour picker (hyprpicker) |
| `Print` | Screenshot region |
| `SHIFT + Print` | Screenshot window |
| `SUPER + Print` | Screenshot output |
| `SUPER + SHIFT + C` | Screenshot region (alt) |
| `SUPER + SHIFT + A` | Screenshot region to clipboard |
| `SUPER + {left,right,up,down}` | Focus direction |
| `SUPER + SHIFT + {left,right,up,down}` | Swap window in direction |
| `SUPER + CTRL + {left,right,up,down}` | Resize window (repeating, 20 px) |
| `SUPER + ALT + {left,right}` | Focus monitor |
| `SUPER + SHIFT + ALT + {left,right}` | Move window to monitor |
| `SUPER + {1..9,0}` | Focus workspace 1–10 |
| `SUPER + SHIFT + {1..9,0}` | Move window to workspace |
| `SUPER + SHIFT + ALT + {1..9,0}` | Move window silently |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Toggle pseudotile |
| `SUPER + J` | Toggle split |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + SHIFT + F` | Toggle maximize |
| `SUPER + SHIFT + P` | Pin window |
| `SUPER + CTRL + C` | Center window |
| `SUPER + grave` | Raise window to top |
| `SUPER + G` | Toggle window group |
| `SUPER + SHIFT + G` | Lock window group |
| `SUPER + TAB` / `SUPER + SHIFT + TAB` | Next/previous in group |
| `SUPER + CTRL + TAB` | Move window in group |
| `SUPER + S` / `SUPER + SHIFT + S` | Toggle scratchpad / move window there |
| `SUPER + R` | Enter resize submap (arrows resize, Esc/Enter exit) |
| `SUPER + mouse_down/up` | Next/previous workspace |
| `SUPER + mouse drag` / `SUPER + right drag` | Move / resize window |
| `ALT + Tab` | Cycle windows (X11-style MRU) |
| `XF86Audio*` | `wpctl` volume/mute, `playerctl` media |
| `XF86MonBrightness*` | `brightnessctl` 10 % steps |

Volume, brightness and media binds use `locked = true` so they keep working on the lock screen.

---

## Packages

`archiso/packages.x86_64` — installed in the Arch live system:

| Group | Key packages |
|---|---|
| Base | base, linux, linux-firmware, intel-ucode, amd-ucode |
| Initramfs | mkinitcpio, **mkinitcpio-archiso**, archlinux-keyring |
| Install/boot | grub, efibootmgr, mtools, os-prober, syslinux, arch-install-scripts, parted, gptfdisk, dosfstools, e2fsprogs, exfatprogs, ntfs-3g |
| GPU | mesa, vulkan-icd-loader, vulkan-radeon, vulkan-intel |
| Audio hw | sof-firmware, alsa-firmware, alsa-ucm-conf, alsa-utils |
| Desktop | hyprland, greetd, xorg-xwayland, waybar, mako, hyprlock, hypridle, hyprpicker, rofi, rofi-emoji, kitty, foot |
| Audio | pipewire, pipewire-alsa, pipewire-pulse, **pipewire-audio**, wireplumber, gst-plugin-pipewire, pavucontrol, playerctl |
| Network | networkmanager, iw, wireless-regdb, bluez, bluez-utils, openssh |
| Power | zram-generator, tlp |
| Gaming/maint | gamescope, gamemode, mangohud, earlyoom, fwupd, flatpak |
| KDE | dolphin, kio-extras, ark, ffmpegthumbs, kimageformats, breeze-icons, kde-cli-tools, qt6-multimedia |
| Qt/portal | qt5-wayland, qt6-wayland, qt5ct, qt6ct, kvantum, kvantum-theme-materia, xdg-desktop-portal{,-hyprland,-gtk}, xdg-user-dirs, xdg-utils, polkit, polkit-gnome, gnome-keyring, libsecret |
| Shell/apps | zsh, zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, starship, neovim, vim, nano, cava, ranger, fastfetch, btop, htop, imv, mpv, zathura, zathura-pdf-mupdf |
| Dev | git, curl, wget, python, ripgrep, fd, fzf, jq, tree-sitter |
| Brave deps | gtk3, libxss, nss, alsa-lib, ttf-dejavu |
| Fonts | ttf-jetbrains-mono, ttf-jetbrains-mono-nerd, ttf-nerd-fonts-symbols, otf-font-awesome, noto-fonts, noto-fonts-emoji, terminus-font |
| Theme | papirus-icon-theme, adwaita-icon-theme, gnome-themes-extra |
| Wayland tools | cliphist, wl-clipboard, grim, slurp |
| Utils | udisks2, procps-ng, psmisc, util-linux, rsync, pv, less, man-db, man-pages, bash-completion, zip, unzip, 7zip |

**`archiso/airootfs/usr/local/share/axyl/packages.target`** is the list `axyl-install` actually pacstraps. It is *not* identical to `packages.x86_64`: it targets an installed system (adds `sudo`, drops live-only tooling, adds `grub`, `xdg-desktop-portal-hyprland`, `chrony`/`zramen` on Artix). Keep both lists in sync whenever a runtime dependency changes.

`artixiso/packages.x86_64` differs from the Arch list by: `artix-keyring` instead of `archlinux-keyring`; every daemon paired with its `-runit` package (`dbus-runit`, `elogind-runit`, `networkmanager-runit`, `greetd-runit`, `bluez-runit`, `earlyoom-runit`, `chrony-runit`, `zramen-runit`); `elogind` (provides `loginctl`), `runit`, `device-mapper`, `udev`, `openssl`; `chrony` instead of systemd-timesyncd; `zramen` instead of zram-generator; `greetd`/`greetd-runit`; **no** `mkinitcpio-archiso` and **no** `arch-install-scripts` (their payloads ship in `artixiso/airootfs`).

### Gaming, firmware, microphones

- `axyl-game` wraps a command with `gamemoderun` and `MANGOHUD=1`; `--gamescope` runs it in a nested gamescope window sized by `AXYL_GAME_WIDTH/HEIGHT/REFRESH` (default 1920x1080@60). It ships **once** in `archiso/airootfs/usr/local/bin/` and is inherited by the Artix overlay — do not duplicate it there.
- `skel/.config/MangoHud/MangoHud.conf` and `skel/.config/pipewire/pipewire.conf.d/99-axyl-echo-cancel.conf` arrive through `/etc/skel`; no extra package is needed for echo cancellation (`pipewire-audio` pulls in `webrtc-audio-processing`).
- Early OOM: `earlyoom.service` on Arch, `earlyoom` runit service on Artix. `fwupd-refresh.timer` is Arch-only; fwupd on Artix is D-Bus activated, so firmware metadata refresh is manual.
- No 32-bit/multilib gaming stack is shipped; `archiso/pacman.conf` still lists `[multilib]` for the build host only.

---

## Artix Variant

### Docker build host (`docker/Dockerfile.artix`)

`artixlinux/artixlinux:base-runit`, curated mirrorlist, then `archiso`, `arch-install-scripts`, `dosfstools`, `e2fsprogs`, `libisoburn`, `mtools`, `squashfs-tools`, `syslinux`, `grub`, `mkinitcpio`, `git`.

The Arch `[extra]` repo is appended to the container's `pacman.conf` with `SigLevel = Never`. The section **must** be named `[extra]` — pacman fetches `<section>.db`, so a custom name requests a non-existent `.db` and 404s. `grub` is mandatory on the build host for `uefi-x64.grub.esp`.

### Repo structure (`artixiso/pacman.conf`)

`[system]`, `[world]`, `[galaxy]` via `Include = /etc/pacman.d/mirrorlist`, plus Arch `[extra]` from `geo.mirror.pkgbuild.com` with `SigLevel = Never`. `[artix]` is an internal, unmirrored repo and is never used. Artix packages remain signature-verified; `Never` applies only to the build-only `[extra]`.

### Initramfs preset bypass

Artix's `mkinitcpio` (from `[world]`) generates a `Configuration: archiso` INI section header in the merged temp file when `mkinitcpio-archiso`'s drop-in is present, then tries to source it as bash:

```
/tmp/mkinitcpio.XXXXXX: line 5: Configuration: command not found
==> ERROR: Failed to read configuration
```

The authoritative initramfs is therefore rebuilt explicitly in `customize_airootfs.sh` (and by `axyl-install` for the target):

```bash
mkinitcpio -c /etc/mkinitcpio.conf -k /boot/vmlinuz-linux -g /boot/initramfs-linux.img
```

No preset, no drop-in. A failure at pacman hook step 15/25 is expected and harmless.

### Power commands — `loginctl` / `sv`, not `systemctl`

Artix has no systemd. Rules:

- `systemctl reboot|poweroff|suspend` → `loginctl ...` (elogind)
- `systemctl enable|disable` → `ln -sf /etc/runit/sv/<svc> /etc/runit/runsvdir/default/` / `rm -f` + `sv down`
- `systemctl is-active` → `sv status <svc>`

Scripts must branch at runtime rather than assume one init: `rofi/services.sh`, `axyl-setup`, `start-audio.sh`, and `axyl-install` all test for `/run/systemd/system`. Because of that runtime branching, `artixiso/airootfs/usr/local/bin/{axyl-install,axyl-setup,start-hyprland-session,brave-wayland}` are currently **byte-identical copies** of the `archiso` versions — redundant, but harmless (the overlay is what wins).

### Services shipped by the overlay

| Service | Source | Notes |
|---|---|---|
| `axyl-tune` | overlay `run` | applies `99-zram.conf` once, then `fstrim -av` at boot and weekly; loops forever so runsv does not restart it |
| `tlp` | overlay `run`/`finish` | `tlp start` then `exec pause`; `finish` runs `tlp stop` |
| `zramen` | `zramen-runit` + overlay `conf` | 50 % of RAM, capped at 4096 MB, zstd, priority 100 |
| `chrony` | `chrony-runit` | live clock sync (Arch uses systemd-timesyncd) |
| `earlyoom` | `earlyoom-runit` | OOM protection |
| `dbus`, `NetworkManager`, `greetd`, `bluetoothd`, `agetty-tty2` | `*-runit` packages | enabled by symlink |

### Live Artix UEFI GRUB rules

- Microcode initrds are **not** in the `x86_64` subdirectory:
  `initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img`
- `loadfont unicode` must run **before** `terminal_output gfxterm`, otherwise box-drawing borders render as `?`.
- `uefi.systemd-boot` MUST NOT be used on Artix (`install: cannot stat '.../systemd-bootx64.efi'`).

---

## Installer (`axyl-install`)

One script for both variants; it reads `/etc/axyl/variant` to pick the OS label, runit symlinks, and initramfs command.

```bash
sudo axyl-install                                   # interactive, requires typing ERASE
sudo axyl-install --auto --disk /dev/sda --yes --password '...'   # unattended
```

Options: `--auto`, `--disk`, `--password`/`AXYL_PASSWORD`, `--yes`, `--allow-usb`, `--user`, `--hostname`, `--timezone` (defaults `axyl`/`axyl`/`Asia/Manila`).

Safety rules that must not be relaxed:

- refuses non-block devices and non-whole disks
- refuses the live/root disk (checks `/run/archiso/bootmnt`, `/run/archiso/img_dev`, and `/`)
- refuses USB targets unless `--allow-usb`
- refuses disks below 8 GiB and disks with mounted partitions
- `--auto` additionally requires `--yes`

Layout: GPT, 512 MiB EFI (`ef00`) for UEFI or 1 MiB BIOS boot (`ef02`), remainder ext4 labelled `AXYL`; root mounted at `/mnt`, ESP at `/mnt/boot`.

Steps: `pacstrap -K` the variant's `/usr/local/share/axyl/packages.target` (retry without `-K` on keyring failure) → `genfstab -U` → `noatime` on `/`, `fmask=0077,dmask=0077` on `/boot` → copy `/etc/skel`, `start-hyprland-session`, `brave-wayland`, `axyl-setup`, `axyl-game`, the vendored Brave package, os-release/variant/mirrorlist/hook/locale → rewrite `mkinitcpio.conf` (`MODULES=(virtio_blk virtio_pci virtio_net virtio_gpu)`, add `microcode` hook) → drop `resolve` from `nsswitch.conf` → copy TLP/zram/sysctl config and (Artix) the `tlp`/`axyl-tune`/`zramen` service dirs → write greeter-only `greetd/config.toml` and `/etc/default/grub` (`GRUB_TIMEOUT=2`, `quiet zswap.enabled=0`) → create groups/user, lock root, enable `wheel` sudo, timezone, locale, `xdg-user-dirs-update`, regenerate the user's theme files → install Brave into the target → enable services → `mkinitcpio -P` (Arch) or explicit `mkinitcpio -c/-k/-g` (Artix) → `grub-install` + `grub-mkconfig` → unmount.

The installer is copy-based: it does **not** reinstall the live ISO and does not touch the live root. It also does not keep passwordless sudo for the target user.

`axyl-setup` (`sudo axyl-setup`) re-applies the installed-system half of that work on an existing install: greeter-only greetd config, service enablement for the detected init, xdg dirs, theme render.

---

## Build, Flash, Test Commands

```bash
# Build (Docker, no root needed)
./build.sh arch
./build.sh artix

# Flash to USB (lists USB devices only, verifies .sha256, requires typing FLASH)
sudo ./flash.sh
sudo ./flash.sh axyl-out/arch/axyl-arch-*.iso

# QEMU harness
./test.sh                     # menu of built ISOs
./test.sh arch                # newest arch ISO, BIOS, persistent disk
./test.sh artix --uefi        # OVMF with per-VM NVRAM
./test.sh arch --snapshot     # discard disk writes
./test.sh arch --boot disk    # boot the installed system, no ISO
./test.sh arch --share ~/Pictures
./test.sh arch --headless --gl --verify --dry-run
```

`test.sh` keeps disks and QMP sockets in `~/axyl-qemu/`; `--headless` drives the VM through QMP (`python3 ~/axyl-qemu/qmp.py <sock> shot out.ppm`). Hyprland needs a DRM/EGL-capable virtual GPU: prefer `-device virtio-vga-gl -display gtk,gl=on`.

Raw QEMU equivalents are documented in `README.md`.

---

## Live System Credentials

| Account | Password | Notes |
|---|---|---|
| `axyl` | `axyl` | Default user, passwordless sudo (live only), shell `/bin/zsh` |
| `root` | `toor` | Root account |

Live timezone `Asia/Manila`, hostname `axyl`, clock synced by systemd-timesyncd (Arch) or chrony (Artix). Installed systems get a chosen timezone and a greeter instead of autologin.

---

## Known Pitfalls

### Hyprland / Wayland

| Symptom | Cause | Fix |
|---|---|---|
| Edits to `~/.config/hypr/*.conf` do nothing | Hyprland loads `hyprland.lua` when present (≥ 0.55) | Edit `conf/*.lua`; there is no `hyprland.conf` |
| Colours or layout revert after re-login | `palette.lua`, `design.lua`, `waybar/config`, `style.css`, `mako/config`, `hyprlock.conf`, GTK/KDE files are generated | Change `theme/palette.json` / `theme/designs.json`, then run `render.py` |
| Theme picker has no effect | `themes.py set` writes `palette.json` + `cli.json` then re-renders; a render failure restores the old palette | Check `~/.config/opencode/cli.json` and stderr |
| Gaps, rounding and blur stop applying | `appearance.lua` reads `conf/design.lua`, which `render.py` generates | Run `render.py`; a missing `design.lua` makes the whole appearance module fail |
| Bar missing after switching to `violet` | the dock is `position: bottom` with `margin-bottom: 16` | expected; `themes.py set ember` returns it to the top |
| Hand edits to `waybar/config` or `waybar/style.css` vanish | both are generated from the layout block | Edit `designs.json` / `render.py`, then re-render |
| `hyprctl keyword ...` returns "unknown request" | Lua config on Hyprland 0.5x | Use `hyprctl eval "hl.config({...})"` |
| Black screen / no cursor in QEMU | no usable hardware cursor or no EGL render node | `start-hyprland-session` sets `WLR_NO_HARDWARE_CURSORS=1`; pass `-device virtio-vga-gl -display gtk,gl=on`; only VMs without `/dev/dri/renderD128` fall back to `WLR_RENDERER=pixman` |
| Waybar battery pill missing | `waybar-battery` prints empty text for an absent pack and Waybar hides empty custom modules | Expected on single-battery machines; `BAT1` reappears on hotplug |
| No clipboard history | `wl-paste --watch cliphist store` not running | It is in `conf/autostart.lua`; restart the session or run it manually |
| Screenshots fail | `grim`/`slurp`/`jq`/`wl-clipboard` missing, or not on Wayland | Keep those packages; `screenshot window` needs `hyprctl` + `jq` |
| Audio silent on Arch | PipeWire started manually instead of via systemd user units | Use `~/.local/bin/start-audio.sh`; it prefers `systemctl --user` and only falls back to manual daemons |
| Audio silent on Artix | no systemd user manager | `start-audio.sh` starts `pipewire`, `wireplumber`, `pipewire-pulse` directly and waits for the socket |
| Locked screen ignores volume/brightness | binds missing `locked = true` | Keep it on media/volume/brightness binds |
| Qt apps look unthemed | `QT_QPA_PLATFORMTHEME`/`QT_STYLE_OVERRIDE` unset | Session sets `qt6ct` + `kvantum`; `~/.config/environment.d/qt-theme.conf` mirrors it |

### Build system

| Symptom | Cause | Fix |
|---|---|---|
| Overlay files are `0644` in the live system | `profiledef.sh` used `declare -A file_permissions` | Use a plain `file_permissions=( ... )` assignment |
| `Hook 'archiso' cannot be found` | `archiso` in `packages.x86_64` instead of `mkinitcpio-archiso` | Use `mkinitcpio-archiso` (Arch variant) |
| `Hook 'archiso_shutdown' cannot be found` | hook removed upstream | Remove it from `HOOKS` |
| `Hook 'archiso_kms' is deprecated` | old hook name | Use `kms` |
| `install: cannot stat '.../systemd-bootx64.efi'` | `uefi.systemd-boot` on Artix | `artixiso/profiledef.sh` must use `uefi-x64.grub.esp`; `grub` must be in `docker/Dockerfile.artix` |
| `pacman -U brave-bin` fails with `CheckSpace` | no mount table for `/` inside the mkarchiso chroot | Both `customize_airootfs.sh` and `axyl-install` retry with only `CheckSpace` commented out |
| Build picks up stale config | builder image is always removed and rebuilt; profile is a fresh `mktemp -d` | If something still looks stale, check `axyl-build/pkgs/` for an old `brave-bin` package |
| ISO name/label mismatch | `iso_label` uses `%y.%m`; `install_dir` is `arch` on both variants | Do not change `install_dir` without updating syslinux, GRUB, systemd-boot, and `profiledef.sh` |

### Artix build errors

| Symptom | Cause | Fix |
|---|---|---|
| `Configuration: command not found` in a pacman hook (15/25) | Artix `mkinitcpio` + Arch-format drop-in | Rebuild with explicit `mkinitcpio -c/-k/-g` in `customize_airootfs.sh`; the hook failure is expected |
| `useradd: group 'storage' does not exist` | `esysusers` hooks do not run in the mkarchiso chroot | `groupadd -f` the full group list before `useradd` |
| `KERNEL PANIC! VFS: Unable to mount root fs` | `isofs` absent from the initramfs | Add `isofs` to `MODULES=` in `artixiso/etc/mkinitcpio.conf` |
| GRUB borders render as `?` | `terminal_output gfxterm` before `loadfont unicode` | Load the font first inside `if loadfont unicode; then` |
| GRUB `file .../boot/x86_64/intel-ucode.img not found` | microcode images live in `boot/`, not `boot/x86_64/` | Fix the initrd paths |
| `systemctl: command not found` | no systemd on Artix | Branch on `/run/systemd/system`, or use `loginctl`/`sv` |
| Two supervisors for one daemon | enabling both `logind` and `elogind` | `elogind-runit` already enables `logind`; never add `elogind` |
| `ttys 1,3,4,5,6` still prompt | runit gettys not removed | Remove the `agetty-tty*` symlinks; keep only `agetty-tty2` |
| Wi-Fi/Bluetooth toggle does nothing on Artix | `rofi/services.sh` used systemd commands | It detects runit and uses `sv`/`runsvdir`; verify the `-runit` package is installed |

### Shell / dotfiles

| Symptom | Cause | Fix |
|---|---|---|
| `command not found: export` on line 1 of `.zshrc` | UTF-8 BOM prepended by a Windows editor | Strip the BOM; write without BOM |
| Script does not execute at all | BOM before `#!` hides the shebang | Same fix; verify the first three bytes are not `EF BB BF` |
| `nvim` tries to download plugins at login | lazy bootstrap cannot fetch | The plugin tree is vendored in `skel/.local/share/nvim/lazy`; keep `lazy-bootstrap.lua` offline-safe |
| Nerd Font glyphs show as boxes | font missing or wrong family | Keep `ttf-jetbrains-mono-nerd` + `ttf-nerd-fonts-symbols`; Waybar uses `JetBrainsMono Nerd Font` |
| `.bash_profile` breaks in a POSIX shell | bash-only syntax | Keep `.bash_profile` POSIX (`[ ]`, no `[[ ]]`); `.bashrc` itself may use bash syntax |

### Fonts and special characters

Nerd Font glyphs live in the Unicode Private Use Area and emoji live outside the BMP. Pasting them through a Windows editor can silently drop or corrupt them, so prefer escapes where the format allows one:

- `render.py`'s `waybar_config()` stores module icons as raw UTF-8 bytes (workspaces, CPU, volume, network) and writes them into the generated `skel/.config/waybar/config`.
- `skel/.config/rofi/powermenu.sh` uses `printf '\uf023'`-style escapes instead of raw bytes — both approaches are valid; do not "normalise" one into the other.

Verify the raw-byte file still contains multibyte characters:

```bash
grep -cP "[\x80-\xFF]" skel/.config/waybar/config
```

Expected: non-zero.

---

## Coding Rules

- Shell scripts: `#!/usr/bin/env bash` and `set -euo pipefail`. POSIX helpers under `skel/.local/bin` may use `#!/bin/sh` (e.g. `screenshot`, `waybar-battery`).
- `.bash_profile` must stay POSIX. `.bashrc` is bash-only and may use `[[ ]]`.
- No comments unless the WHY is non-obvious. Never add placeholder or stub code.
- Keep configs minimal: do not add packages or features that were not requested.
- **Never hand-edit generated files.** A file with a `GENERATED by ~/.config/theme/render.py` header is overwritten on every login, by `themes.py`, and by the installer.
- Colour changes go into `~/.config/theme/palette.json`; structural/template changes go into `render.py`.
- `profiledef.sh` uses plain array assignment for `file_permissions` (see above).
- Every new executable must be added to **both** variants' `file_permissions`, to the matching `chmod` loop in `customize_airootfs.sh`, and — if it lives in `/usr/local/bin` — copied by `axyl-install`.
- Scripts that run on both variants must branch on `/run/systemd/system` (or use `loginctl`); `systemctl` may never be called unconditionally.
- PowerShell writes must never include a BOM:
  ```powershell
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8)
  ```

---

## Dependency Management

**Never assume a dependency is available. Verify it.**

For every new feature:

1. Identify every binary, library, service, and config file it references.
2. Trace each to its Arch package **and** its Artix equivalent (`-runit` companion for daemons).
3. Add it to `packages.x86_64` (live) and, if the installed system needs it, to `packages.target`.
4. Update the Artix lists where the package differs (`zramen`, `chrony`, `elogind`, runit pairs).
5. Check nothing conflicts (e.g. `pipewire` vs `pulseaudio`, `polkit-gnome` vs `hyprpolkitagent`).

Examples already enforced: `screenshot` needs `grim slurp jq wl-clipboard libnotify`; `keybinds.sh` needs `python` + `rofi`; `battery-guard` needs `python`; `wpctl` needs `wireplumber`; `pactl` needs `pipewire-pulse`; `cliphist` needs `wl-clipboard`; theme engine needs `python`; Brave needs `gtk3 libxss nss alsa-lib ttf-dejavu`.

---

## Task Tracking (TODOs)

**Every task Claude performs must be tracked as a TODO.**

- Write the TODO list with `TodoWrite` before starting any work.
- Mark each item complete immediately when done — do not batch completions.
- Never leave a TODO open at the end of a session without noting its status.
- TODOs must be granular: one action per item.

---

## File Structure Checks

Run mentally after every edit session:

- Every binary referenced in `skel/**`, `airootfs/usr/local/bin/**`, and `airootfs/etc/runit/sv/**` has a package in the matching `packages.x86_64` (and `packages.target` if installed systems use it).
- Every script under `airootfs/usr/local/bin/`, `skel/.local/bin/`, `skel/.config/rofi/*.sh`, `skel/.config/theme/*.py`, and the Artix runit services appears in that variant's `file_permissions` at `0:0:755`.
- `profiledef.sh` uses a plain `file_permissions=( ... )` assignment.
- `mkinitcpio.conf` HOOKS contain no removed/deprecated hook names; Artix includes `isofs`.
- Arch live UEFI uses `uefi.systemd-boot`; Artix live UEFI uses `uefi-x64.grub.esp` and `artixiso/grub/grub.cfg` exists with `/%INSTALL_DIR%/boot/intel-ucode.img` (no `x86_64` subdir).
- `greetd/config.toml` keeps `[initial_session]` in **both** live overlays; the installer-written target config must not have it.
- `/etc/axyl/variant` says `arch` in `archiso/`, `artix` in `artixiso/`.
- Generated files still carry their GENERATED header; no hand edits accumulate.
- Every daemon enabled in `customize_airootfs.sh` has a base package **and** a `-runit` companion in `artixiso/packages.x86_64`.
- No script calls `systemctl` unconditionally; Artix paths use `loginctl`/`sv` or runtime detection.
- `axyl-game` exists once (in `archiso/`) and is listed in both `file_permissions` files, both `chmod` loops, and both `packages.target` blocks.
- The gaming/maintenance block stays in sync between `packages.x86_64` and `packages.target` (`earlyoom-runit` only on Artix).
- Vendored `skel/.local/share/nvim/lazy` is intact; `lazy-lock.json` matches it.

---

## Workflow Checklist

```
[ ] Write TODOs before starting
[ ] Read the codebase and identify files that are no longer needed; confirm before deleting
[ ] Identify all new dependencies (Arch + Artix); add to packages.x86_64 / packages.target
[ ] Edit or create the relevant files
[ ] Verify file structure is still consistent
[ ] Update README.md — always; every task that changes behaviour, commands, files, or defaults must be reflected in README.md
[ ] Update CLAUDE.md when architecture, paths, packages, or pitfalls change
[ ] Mark all TODOs complete (or annotate blockers)
```

---

## Known Inconsistencies (fix when touched)

- `artixiso/airootfs/usr/local/bin/{axyl-install,axyl-setup,start-hyprland-session,brave-wayland}` are byte-identical to the `archiso` originals; the overlay copies are redundant.
- `README.md` still says `mkinitcpio-archiso` and `arch-install-scripts` come from Arch `[extra]` during the Artix build. In practice both payloads ship in `artixiso/airootfs` and neither package is in `artixiso/packages.x86_64`.
- `artixiso/pacman.conf` keeps the Arch `[extra]` section although the Artix live list no longer pulls from it.
