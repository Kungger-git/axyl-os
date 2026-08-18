#!/usr/bin/env bash
set -euo pipefail

# ── Keyring ──────────────────────────────────────────────────────────────────
pacman-key --init
pacman-key --populate artix

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

# ── Initramfs ────────────────────────────────────────────────────────────────
# The linux.preset (modified by mkinitcpio-archiso) loads the 'archiso' drop-in.
# Artix's mkinitcpio generates a 'Configuration: archiso' section header in the
# merged temp file — valid in its new INI format but not sourceable as bash,
# so the pacman hook (step 15/25) always fails and produces no initramfs-linux.img.
# Bypass the preset entirely: call mkinitcpio with explicit -c/-k/-g flags so
# no preset is read and no drop-in is loaded.
mkinitcpio \
    -c /etc/mkinitcpio.conf \
    -k /boot/vmlinuz-linux \
    -g /boot/initramfs-linux.img

# ── runit services ───────────────────────────────────────────────────────────
# Each *-runit package installs run scripts in /etc/runit/sv/<service>/.
# Enable by symlinking into runsvdir/default — runit starts all on boot.
# Order: dbus and elogind first (greetd and NM depend on them at runtime;
# their own run scripts check readiness via sv-status or socket tests).
RUNIT_DEFAULT="/etc/runit/runsvdir/default"
mkdir -p "$RUNIT_DEFAULT"
for svc in dbus elogind NetworkManager greetd acpid bluetoothd; do
    if [ -d "/etc/runit/sv/$svc" ]; then
        ln -sf "/etc/runit/sv/$svc" "$RUNIT_DEFAULT/"
    else
        echo "WARNING: /etc/runit/sv/$svc not found — check *-runit package" >&2
    fi
done

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.oh-my-zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# ── Live user ────────────────────────────────────────────────────────────────
# Artix esysusers hooks may not have run inside the mkarchiso chroot, so some
# groups (storage, optical) might not exist yet. -f = ignore if already exists.
for grp in wheel audio video input storage optical network; do
    groupadd -f "$grp"
done
useradd -m -G wheel,audio,video,input,storage,optical,network -s /bin/zsh axyl
echo "axyl:axyl" | chpasswd
echo "root:toor"  | chpasswd

echo "axyl ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/axyl
chmod 0440 /etc/sudoers.d/axyl
chown root:root /etc/sudoers.d/axyl

sudo -Hu axyl xdg-user-dirs-update

# ── Executable bits ──────────────────────────────────────────────────────────
chmod +x \
    /usr/local/bin/start-bspwm-session \
    /usr/local/bin/axyl-install \
    /usr/local/bin/axyl-setup \
    /usr/local/bin/axyl-powermenu \
    /usr/local/bin/axyl-lock \
    /usr/local/bin/axyl-osd-volume \
    /usr/local/bin/axyl-osd-brightness

# ── Font cache ───────────────────────────────────────────────────────────────
fc-cache -fv

# ── Cleanup ───────────────────────────────────────────────────────────────────
pacman -Scc --noconfirm