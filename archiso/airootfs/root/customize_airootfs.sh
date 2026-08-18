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
systemctl enable bluetooth.service
systemctl set-default graphical.target

# ── Executable bits (file_permissions handles mkarchiso; this is the safety net) ──
chmod +x \
    /usr/local/bin/start-bspwm-session \
    /usr/local/bin/axyl-install \
    /usr/local/bin/axyl-setup \
    /usr/local/bin/axyl-powermenu \
    /usr/local/bin/axyl-lock \
    /usr/local/bin/axyl-osd-volume \
    /usr/local/bin/axyl-osd-brightness

# ── Oh My Zsh (cloned into skel so useradd -m copies it to /home/axyl/) ──────
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.oh-my-zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# ── Live user ────────────────────────────────────────────────────────────────
for grp in wheel audio video input storage optical network; do
    groupadd -f "$grp"
done
useradd -m -G wheel,audio,video,input,storage,optical,network -s /bin/zsh axyl
echo "axyl:axyl" | chpasswd
echo "root:toor"  | chpasswd

# axyl gets passwordless sudo for the live session
echo "axyl ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/axyl
chmod 0440 /etc/sudoers.d/axyl
chown root:root /etc/sudoers.d/axyl

sudo -Hu axyl xdg-user-dirs-update

# ── Font cache ───────────────────────────────────────────────────────────────
fc-cache -fv

# ── Cleanup ───────────────────────────────────────────────────────────────────
pacman -Scc --noconfirm
