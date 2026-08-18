#!/usr/bin/env bash
# Usage: sudo ./setup.sh
# First run on a new clone: chmod +x setup.sh
set -euo pipefail

ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
RESET='\e[0m'

info() { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()   { echo -e "${GREEN} ok ${RESET}$*"; }
err()  { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
note() { echo -e "${MUTED}    $*${RESET}"; }

[[ $EUID -ne 0 ]] && err "Run as root: sudo ./setup.sh"
[[ -f /etc/arch-release ]] || err "This script is for Arch Linux only."

info "Axyl Linux -- dependency setup"
echo ""

# Docker -- required for both build variants
info "Installing Docker..."
if pacman -Q docker &>/dev/null; then
    ok "docker already installed"
else
    pacman -S --noconfirm --needed docker
    ok "docker installed"
fi

if pacman -Q docker-buildx &>/dev/null; then
    ok "docker-buildx already installed"
else
    pacman -S --noconfirm --needed docker-buildx
    ok "docker-buildx installed (eliminates legacy builder warning)"
fi

systemctl enable --now docker.service
ok "docker service enabled and started"
note "To run Docker without sudo:"
note "  sudo usermod -aG docker \$USER  (then log out and back in)"
echo ""

# QEMU -- optional, for ISO testing
info "QEMU testing dependencies (optional)..."
echo -ne "${ACCENT}    Install QEMU + OVMF for ISO testing? [y/N]: ${RESET}"
read -r -t 15 QEMU_CHOICE || QEMU_CHOICE="n"

if [[ "${QEMU_CHOICE,,}" == "y" ]]; then
    pacman -S --noconfirm --needed qemu-system-x86 edk2-ovmf
    ok "QEMU packages installed"
    note "Test BIOS:  qemu-system-x86_64 -cdrom axyl-out/*.iso -m 2G -boot d"
    note "Test UEFI:  qemu-system-x86_64 -cdrom axyl-out/*.iso -m 2G -bios /usr/share/ovmf/x64/OVMF.fd"
else
    note "Skipping QEMU"
fi
echo ""

ok "Setup complete. Build with: ./build.sh [arch|artix]"
