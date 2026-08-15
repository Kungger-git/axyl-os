#!/usr/bin/env bash
set -euo pipefail

# ── Keyring (must be first) ──────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux

# ── Locale & timezone ────────────────────────────────────────────────────────
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# ── Hostname ─────────────────────────────────────────────────────────────────
echo "axyl" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   axyl.localdomain axyl
EOF

# ── Services ─────────────────────────────────────────────────────────────────
systemctl enable NetworkManager.service
systemctl enable greetd.service
systemctl enable acpid.service
systemctl enable polkit.service
systemctl set-default graphical.target

# ── Live user ────────────────────────────────────────────────────────────────
useradd -m -G wheel,audio,video,input,storage,optical,network -s /bin/bash axyl
echo "axyl:axyl" | chpasswd
echo "root:toor"  | chpasswd

# axyl gets passwordless sudo for the live session
echo "axyl ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/axyl
chmod 0440 /etc/sudoers.d/axyl
chown root:root /etc/sudoers.d/axyl

sudo -u axyl xdg-user-dirs-update

# ── AUR: paru-bin + brave-bin (from pre-downloaded tarballs) ─────────────────
# Tarballs must be placed at archiso/airootfs/root/aur-cache/ before running
# mkarchiso. See README for the pre-build download step.
if [[ -d /root/aur-cache/paru-bin ]]; then
    useradd -m -r aur_builder
    echo "aur_builder ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/aur_builder
    chmod 0440 /etc/sudoers.d/aur_builder
    chown root:root /etc/sudoers.d/aur_builder

    chown -R aur_builder:aur_builder /root/aur-cache

    cd /root/aur-cache/paru-bin
    sudo -u aur_builder makepkg -si --noconfirm --skippgpcheck

    if [[ -d /root/aur-cache/brave-bin ]]; then
        cd /root/aur-cache/brave-bin
        sudo -u aur_builder makepkg -si --noconfirm --skippgpcheck
    fi

    userdel -r aur_builder
    rm -f /etc/sudoers.d/aur_builder
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
paccache -r -k0 || true
rm -rf /root/aur-cache
