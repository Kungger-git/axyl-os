#!/usr/bin/env bash
# Usage: sudo ./flash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$SCRIPT_DIR/axyl-out"

ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
FG='\e[38;2;230;225;216m'
BOLD='\e[1m'
RESET='\e[0m'

info() { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()   { echo -e "${GREEN} ✓  ${RESET}$*"; }
err()  { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
warn() { echo -e "${RED} !  ${RESET}$*"; }
note() { echo -e "${MUTED}    $*${RESET}"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root: sudo ./flash.sh"

# ── Find ISO ──────────────────────────────────────────────────────────────────
mapfile -t ISOS < <(ls "$ISO_DIR"/axyl-*.iso 2>/dev/null || true)
[[ ${#ISOS[@]} -eq 0 ]] && err "No Axyl ISO found in axyl-out/. Run ./build.sh first."
ISO="${ISOS[-1]}"
ISO_NAME=$(basename "$ISO")
ISO_SIZE=$(du -h "$ISO" | awk '{print $1}')
ISO_BYTES=$(stat -c%s "$ISO")

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo -e "${ACCENT}"
cat << 'BANNER'
     _   __  ____  __
    / | / / / /\ \/ /
   /  |/ / / /  \  /
  / /|  / / /___/ /
 /_/ |_/_/_____/_/
BANNER
echo -e "${MUTED}         USB Flasher${RESET}"
echo ""
note "ISO  : $ISO_NAME"
note "Size : $ISO_SIZE"
echo ""

# ── Detect system drive (exclude from list) ───────────────────────────────────
ROOT_SOURCE=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's|/dev/||') || ROOT_SOURCE=""
ROOT_DRIVE=$(lsblk -no PKNAME "/dev/$ROOT_SOURCE" 2>/dev/null | tr -d '[:space:]') || ROOT_DRIVE=""
[[ -z "$ROOT_DRIVE" ]] && ROOT_DRIVE="$ROOT_SOURCE"

# ── Enumerate drives ──────────────────────────────────────────────────────────
info "Available drives:"
echo ""
printf "  ${MUTED}%-6s  %-12s  %-8s  %-6s  %s${RESET}\n" "Sel" "Device" "Size" "Type" "Model"
printf "  ${MUTED}%-6s  %-12s  %-8s  %-6s  %s${RESET}\n" "---" "------" "----" "----" "-----"

declare -a VALID_DRIVES=()
idx=1

while IFS= read -r name; do
    [[ "$name" == "$ROOT_DRIVE" ]] && continue
    [[ "$name" =~ ^loop ]]         && continue

    size=$(lsblk  -dno SIZE  "/dev/$name" 2>/dev/null || echo "?")
    tran=$(lsblk  -dno TRAN  "/dev/$name" 2>/dev/null | tr -d '[:space:]')
    model=$(lsblk -dno MODEL "/dev/$name" 2>/dev/null | sed 's/[[:space:]]*$//')
    [[ -z "$tran"  ]] && tran="-"
    [[ -z "$model" ]] && model="Unknown"

    VALID_DRIVES+=("$name")
    printf "  ${ACCENT}[%-3d]${RESET}  ${BOLD}%-12s${RESET}  ${FG}%-8s${RESET}  %-6s  ${MUTED}%s${RESET}\n" \
        "$idx" "/dev/$name" "$size" "$tran" "$model"
    (( idx++ )) || true
done < <(lsblk -dno NAME)

echo ""

[[ ${#VALID_DRIVES[@]} -eq 0 ]] && err "No drives found. Insert a USB drive and try again."

# ── Select drive ──────────────────────────────────────────────────────────────
echo -ne "${ACCENT}Select drive [1-${#VALID_DRIVES[@]}]: ${RESET}"
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#VALID_DRIVES[@]} )); then
    err "Invalid selection: $choice"
fi

TARGET="${VALID_DRIVES[$((choice - 1))]}"
TARGET_DEV="/dev/$TARGET"
TARGET_SIZE=$(lsblk -dno SIZE "$TARGET_DEV" | tr -d '[:space:]')
TARGET_BYTES=$(lsblk -dno SIZE --bytes "$TARGET_DEV" 2>/dev/null | tr -d '[:space:]') || TARGET_BYTES=0

# ── Size check ────────────────────────────────────────────────────────────────
if [[ -n "$TARGET_BYTES" ]] && (( TARGET_BYTES > 0 && TARGET_BYTES < ISO_BYTES )); then
    err "Drive too small. ISO is $ISO_SIZE, drive is $TARGET_SIZE."
fi

# ── Unmount all partitions ────────────────────────────────────────────────────
echo ""
info "Unmounting $TARGET_DEV..."
while IFS= read -r part; do
    [[ "$part" == "$TARGET" ]] && continue
    if umount "/dev/$part" 2>/dev/null; then
        note "Unmounted /dev/$part"
    fi
done < <(lsblk -lno NAME "$TARGET_DEV")

# ── Flash ─────────────────────────────────────────────────────────────────────
echo ""
info "Writing to $TARGET_DEV — do not remove the drive..."
echo ""

dd if="$ISO" of="$TARGET_DEV" bs=4M conv=fsync status=progress

echo ""
info "Syncing..."
sync

echo ""
ok "Flash complete. $TARGET_DEV is ready to boot Axyl Linux."
note "You can safely remove the drive."
