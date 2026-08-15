#!/usr/bin/env bash
# Usage: sudo ./build.sh
# First run on a new clone: chmod +x build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/archiso"
AUR_CACHE="$PROFILE_DIR/airootfs/root/aur-cache"
WORK_DIR="/var/tmp/axyl-work"
OUT_DIR="/var/tmp/axyl-out"

# ── Colours ───────────────────────────────────────────────────────────────────
ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
RESET='\e[0m'

info()  { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()    { echo -e "${GREEN} ✓  ${RESET}$*"; }
err()   { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
note()  { echo -e "${MUTED}    $*${RESET}"; }

# ── Preflight checks ──────────────────────────────────────────────────────────
info "Axyl Linux — build script"
echo ""

[[ $EUID -ne 0 ]] && err "This script must be run as root (sudo ./build.sh)"

for cmd in mkarchiso git pacman; do
    command -v "$cmd" &>/dev/null || err "'$cmd' not found. Install it before building."
done

# grub is needed by mkarchiso for the uefi-x64.grub.esp bootmode
pacman -Q grub &>/dev/null || err "'grub' package not installed on build host. Run: sudo pacman -S grub"

ok "Preflight checks passed"
echo ""

# ── AUR cache: paru-bin ───────────────────────────────────────────────────────
info "Setting up AUR cache..."
mkdir -p "$AUR_CACHE"

if [[ -d "$AUR_CACHE/paru-bin/.git" ]]; then
    note "paru-bin already cloned — pulling latest"
    git -C "$AUR_CACHE/paru-bin" pull --ff-only
else
    note "Cloning paru-bin from AUR..."
    git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$AUR_CACHE/paru-bin"
fi
ok "paru-bin ready"

# ── AUR cache: brave-bin ──────────────────────────────────────────────────────
if [[ -d "$AUR_CACHE/brave-bin/.git" ]]; then
    note "brave-bin already cloned — pulling latest"
    git -C "$AUR_CACHE/brave-bin" pull --ff-only
else
    note "Cloning brave-bin from AUR..."
    note "(The PKGBUILD will download the Brave release binary (~350 MB) during the build)"
    git clone --depth=1 https://aur.archlinux.org/brave-bin.git "$AUR_CACHE/brave-bin"
fi
ok "brave-bin ready"
echo ""

# ── Clean previous work directory ────────────────────────────────────────────
if [[ -d "$WORK_DIR" ]]; then
    info "Removing previous work directory..."
    rm -rf "$WORK_DIR"
    ok "Work directory cleared"
fi

mkdir -p "$OUT_DIR"

# ── Build ─────────────────────────────────────────────────────────────────────
info "Building Axyl ISO..."
note "Profile : $PROFILE_DIR"
note "Work dir: $WORK_DIR"
note "Output  : $OUT_DIR"
echo ""

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo ""
ok "Build complete!"
echo ""
info "ISO location:"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null || note "(no .iso found — check mkarchiso output above)"
echo ""
info "Test in QEMU (BIOS):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/\$(ls $OUT_DIR/*.iso | head -1 | xargs basename) -m 2G -boot d"
echo ""
info "Test in QEMU (UEFI — requires edk2-ovmf):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/\$(ls $OUT_DIR/*.iso | head -1 | xargs basename) -m 2G \\"
note "    -bios /usr/share/ovmf/x64/OVMF.fd"
