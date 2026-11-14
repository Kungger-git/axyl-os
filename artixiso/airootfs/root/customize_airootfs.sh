#!/usr/bin/env bash
set -euo pipefail

# ── Keyring ──────────────────────────────────────────────────────────────────
pacman-key --init
pacman-key --populate artix

# ── Locale, timezone, hostname ───────────────────────────────────────────────
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime

echo "axyl" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   axyl.localdomain axyl
EOF

# ── Branding ─────────────────────────────────────────────────────────────────
# Some tools read /usr/lib/os-release directly; keep it in sync with /etc.
install -Dm644 /etc/os-release /usr/lib/os-release

# ── Initramfs ────────────────────────────────────────────────────────────────
# The linux.preset (modified by mkinitcpio-archiso) loads the 'archiso' drop-in.
# Artix's mkinitcpio generates a 'Configuration: archiso' section header in the
# merged temp file -- valid in its new INI format but not sourceable as bash,
# so the pacman hook always fails and produces no initramfs-linux.img.
# Bypass the preset entirely: call mkinitcpio with explicit -c/-k/-g flags so
# no preset is read and no drop-in is loaded.
mkinitcpio \
    -c /etc/mkinitcpio.conf \
    -k /boot/vmlinuz-linux \
    -g /boot/initramfs-linux.img

# ── runit services ───────────────────────────────────────────────────────────
# Each *-runit package installs run scripts in /etc/runit/sv/<service>/.
# Enable by symlinking into runsvdir/default -- runit starts all on boot.
RUNIT_DEFAULT="/etc/runit/runsvdir/default"
mkdir -p "$RUNIT_DEFAULT"
# elogind-runit already enables "logind", which is an alias for the same
# service. Adding "elogind" too would start two supervisors for one daemon.
# chrony keeps the live clock correct once NetworkManager is up.
# tlp and zramen come from *-runit packages; axyl-tune is shipped in this
# overlay and applies the sysctl/zram tunables plus weekly fstrim.
for svc in dbus NetworkManager greetd bluetoothd agetty-tty2 chrony tlp zramen axyl-tune; do
    if [ -d "/etc/runit/sv/$svc" ]; then
        ln -sf "/etc/runit/sv/$svc" "$RUNIT_DEFAULT/"
    else
        echo "WARNING: /etc/runit/sv/$svc not found -- check *-runit package" >&2
    fi
done

# runit ships gettys on tty1-tty6. Keep only tty2 as the documented fallback
# console; greetd owns VT7.
for svc in agetty-tty1 agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6; do
    rm -f "$RUNIT_DEFAULT/$svc"
done

# greetd runs its greeter as this system account; create it if the package
# did not already provide it.
getent group greeter >/dev/null 2>&1 || groupadd -r greeter
getent passwd greeter >/dev/null 2>&1 || \
    useradd -r -M -d /var/lib/greetd -s /usr/bin/nologin greeter
install -d -o greeter -g greeter -m 0755 /var/lib/greetd

# ── Live user ────────────────────────────────────────────────────────────────
# Artix esysusers hooks may not have run inside the mkarchiso chroot, so some
# groups (storage, optical) might not exist yet. -f = ignore if already exists.
for grp in wheel audio video render input storage optical network; do
    groupadd -f "$grp"
done
useradd -m -G wheel,audio,video,render,input,storage,optical,network -s /bin/zsh axyl
echo "axyl:axyl" | chpasswd
echo "root:toor"  | chpasswd

echo "axyl ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/axyl
chmod 0440 /etc/sudoers.d/axyl
chown root:root /etc/sudoers.d/axyl

sudo -Hu axyl xdg-user-dirs-update
sudo -Hu axyl mkdir -p /home/axyl/Pictures/Screenshots

# ── Install the vendored Brave package ───────────────────────────────────────
# pacman's CheckSpace needs a mount table for "/"; inside the mkarchiso chroot
# that lookup can fail even when there is plenty of space. Retry with just
# CheckSpace disabled, keeping every other pacman safeguard in place.
if compgen -G "/usr/local/share/axyl/brave-bin-*.pkg.tar.zst" >/dev/null; then
    if ! pacman -U --noconfirm /usr/local/share/axyl/brave-bin-*.pkg.tar.zst; then
        echo "WARNING: Brave install failed with CheckSpace; retrying without it" >&2
        sed 's/^[[:space:]]*CheckSpace/# CheckSpace/' /etc/pacman.conf > /tmp/pacman-no-check.conf
        pacman -U --noconfirm --config /tmp/pacman-no-check.conf /usr/local/share/axyl/brave-bin-*.pkg.tar.zst
        rm -f /tmp/pacman-no-check.conf
    fi
else
    echo "WARNING: vendored brave-bin package not found" >&2
fi

# ── Executable bits ──────────────────────────────────────────────────────────
for f in \
    /usr/local/bin/start-hyprland-session \
    /usr/local/bin/brave-wayland \
    /usr/local/bin/axyl-install \
    /usr/local/bin/axyl-setup \
    /etc/skel/.local/bin/bt-default-sink.sh \
    /etc/skel/.local/bin/waybar-battery \
    /etc/skel/.local/bin/battery-guard \
    /etc/skel/.local/bin/start-audio.sh \
    /etc/skel/.local/bin/timer \
    /etc/skel/.local/bin/screenshot \
    /etc/skel/.local/bin/hypr-effects \
    /etc/skel/.config/rofi/powermenu.sh \
    /etc/skel/.config/rofi/services.sh \
    /etc/skel/.config/rofi/keybinds.sh \
    /etc/skel/.config/theme/render.py \
    /etc/skel/.config/theme/themes.py \
    /home/axyl/.local/bin/start-audio.sh \
    /home/axyl/.local/bin/bt-default-sink.sh \
    /home/axyl/.local/bin/waybar-battery \
    /home/axyl/.local/bin/battery-guard \
    /home/axyl/.local/bin/timer \
    /home/axyl/.local/bin/screenshot \
    /home/axyl/.local/bin/hypr-effects \
    /home/axyl/.config/rofi/powermenu.sh \
    /home/axyl/.config/rofi/services.sh \
    /home/axyl/.config/rofi/keybinds.sh \
    /home/axyl/.config/theme/render.py; do
    [[ -e "$f" ]] && chmod 0755 "$f"
done

# ── Per-user theme files (must run as the real user) ─────────────────────────
if [[ -x /home/axyl/.config/theme/render.py ]]; then
    sudo -Hu axyl env HOME=/home/axyl /home/axyl/.config/theme/render.py
fi

# ── Font cache ───────────────────────────────────────────────────────────────
fc-cache -fv
sudo -Hu axyl fc-cache -fv

# ── Cleanup ──────────────────────────────────────────────────────────────────
pacman -Scc --noconfirm
