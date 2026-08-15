#!/usr/bin/env bash
# Usage: sudo ./setup.sh
# First run on a new clone: chmod +x setup.sh
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
RESET='\e[0m'

info() { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()   { echo -e "${GREEN} ✓  ${RESET}$*"; }
err()  { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
note() { echo -e "${MUTED}    $*${RESET}"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root: sudo ./setup.sh"

# ── Arch Linux check ─────────────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || err "This script is for Arch Linux only."

info "Axyl Linux — dependency setup"
echo ""

# ── Required build-host packages ─────────────────────────────────────────────
BUILD_DEPS=(
    archiso          # mkarchiso — core ISO build tool
    mkinitcpio       # initramfs builder used by mkarchiso
    dosfstools       # mkfs.fat — EFI partition creation
    e2fsprogs        # mkfs.ext2 — filesystem tools
    libisoburn       # xorriso — ISO 9660 writer
    squashfs-tools   # mksquashfs — live filesystem compression
    grub             # grub-mkstandalone — UEFI EFI image (build-host dep)
    git              # AUR tarball cloning in build.sh
)

# ── Optional: QEMU testing ───────────────────────────────────────────────────
QEMU_DEPS=(
    qemu-system-x86  # qemu-system-x86_64 — BIOS/UEFI VM testing
    edk2-ovmf        # OVMF.fd — UEFI firmware for QEMU
)

# ── Update package databases ──────────────────────────────────────────────────
info "Updating package databases..."
pacman -Sy --noconfirm
ok "Package databases updated"
echo ""

# ── Install build dependencies ────────────────────────────────────────────────
info "Installing build dependencies..."
MISSING=()
for pkg in "${BUILD_DEPS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        note "$pkg — already installed"
    else
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    note "Installing: ${MISSING[*]}"
    pacman -S --noconfirm --needed "${MISSING[@]}"
    ok "Build dependencies installed"
else
    ok "All build dependencies already present"
fi
echo ""

# ── Optional QEMU dependencies ────────────────────────────────────────────────
info "QEMU testing dependencies (optional)..."
echo -ne "${ACCENT}    Install QEMU for ISO testing? [y/N]: ${RESET}"
read -r -t 15 QEMU_CHOICE || QEMU_CHOICE="n"

if [[ "${QEMU_CHOICE,,}" == "y" ]]; then
    MISSING_QEMU=()
    for pkg in "${QEMU_DEPS[@]}"; do
        pacman -Q "$pkg" &>/dev/null || MISSING_QEMU+=("$pkg")
    done
    if [[ ${#MISSING_QEMU[@]} -gt 0 ]]; then
        pacman -S --noconfirm --needed "${MISSING_QEMU[@]}"
        ok "QEMU packages installed"
    else
        ok "QEMU packages already present"
    fi
else
    note "Skipping QEMU packages"
fi
echo ""

# ── Verify key binaries ───────────────────────────────────────────────────────
info "Verifying installed tools..."
TOOLS=(mkarchiso mkinitcpio mkfs.fat mkfs.ext2 xorriso mksquashfs grub-mkstandalone git)
ALL_OK=true
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool"
    else
        echo -e "${RED} ✗  $tool — not found${RESET}"
        ALL_OK=false
    fi
done
echo ""

if $ALL_OK; then
    ok "All tools verified. You are ready to build."
    echo ""
    info "Next step:"
    note "  chmod +x build.sh && sudo ./build.sh"
else
    err "One or more tools missing. Check pacman output above."
fi
