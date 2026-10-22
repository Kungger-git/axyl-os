#!/usr/bin/env bash
set -euo pipefail

# ── Keyring (must be first) ──────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux

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

# ── Services ─────────────────────────────────────────────────────────────────
systemctl enable NetworkManager.service
systemctl enable greetd.service
systemctl enable getty@tty2.service
systemctl enable acpid.service
systemctl enable bluetooth.service
systemctl set-default graphical.target

# greetd runs its greeter as this system account; create it if the package
# did not already provide it.
getent group greeter >/dev/null 2>&1 || groupadd -r greeter
getent passwd greeter >/dev/null 2>&1 || \
    useradd -r -M -d /var/lib/greetd -s /usr/bin/nologin greeter
install -d -o greeter -g greeter -m 0755 /var/lib/greetd

# ── Live user ────────────────────────────────────────────────────────────────
for grp in wheel audio video render input storage optical network; do
    groupadd -f "$grp"
done
useradd -m -G wheel,audio,video,render,input,storage,optical,network -s /bin/zsh axyl
echo "axyl:axyl" | chpasswd
echo "root:toor"  | chpasswd

# axyl gets passwordless sudo for the live session only.
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

# ── Executable bits (file_permissions handles mkarchiso; safety net) ─────────
for f in \
    /usr/local/bin/start-hyprland-session \
    /usr/local/bin/brave-wayland \
    /usr/local/bin/axyl-install \
    /usr/local/bin/axyl-setup \
    /etc/skel/.local/bin/bt-default-sink.sh \
    /etc/skel/.local/bin/start-audio.sh \
    /etc/skel/.local/bin/timer \
    /etc/skel/.config/rofi/powermenu.sh \
    /etc/skel/.config/rofi/keybinds.sh \
    /etc/skel/.config/theme/render.py \
    /etc/skel/.config/theme/themes.py \
    /home/axyl/.local/bin/start-audio.sh \
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
