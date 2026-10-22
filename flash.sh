#!/usr/bin/env bash
# Usage: sudo ./flash.sh [path/to/iso]
# Writes an Axyl ISO to a USB storage device only. Internal disks are never
# listed, and a checksum is verified when a .sha256 file is present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_ROOT="$SCRIPT_DIR/axyl-out"

ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
FG='\e[38;2;230;225;216m'
BOLD='\e[1m'
RESET='\e[0m'

info() { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()   { echo -e "${GREEN} ok ${RESET}$*"; }
err()  { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
warn() { echo -e "${RED} !  ${RESET}$*"; }
note() { echo -e "${MUTED}    $*${RESET}"; }

[[ $EUID -eq 0 ]] || err "Run as root: sudo ./flash.sh"

# ── Select ISO ───────────────────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
    ISO="$1"
else
    mapfile -t ISOS < <(
        find "$ISO_ROOT" -maxdepth 2 -type f -name 'axyl-*.iso' -printf '%T@ %p\n' 2>/dev/null \
            | sort -n | cut -d' ' -f2-
    )
    [[ ${#ISOS[@]} -gt 0 ]] || err "No Axyl ISO found under $ISO_ROOT. Run ./build.sh first."
    ISO="${ISOS[-1]}"
    if [[ ${#ISOS[@]} -gt 1 ]]; then
        echo -e "${MUTED}Multiple ISOs found; using the newest:${RESET} $(basename "$ISO")"
        note "Override with: sudo ./flash.sh /path/to/file.iso"
    fi
fi
[[ -f "$ISO" ]] || err "ISO not found: $ISO"
ISO_NAME="$(basename "$ISO")"
ISO_SIZE="$(du -h "$ISO" | awk '{print $1}')"
ISO_BYTES="$(stat -c%s "$ISO")"

clear
echo -e "${ACCENT}"
cat <<'BANNER'
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

# ── Verify checksum ──────────────────────────────────────────────────────────
SHA_FILE="$ISO.sha256"
if [[ -f "$SHA_FILE" ]]; then
    info "Verifying SHA-256..."
    if (cd "$(dirname "$ISO")" && sha256sum -c "$(basename "$SHA_FILE")"); then
        ok "Checksum verified"
    else
        err "Checksum verification failed; refusing to flash"
    fi
else
    warn "No checksum file found next to $ISO_NAME; skipping verification"
fi
echo ""

# ── Find the live/root disk so it is never offered ───────────────────────────
ROOT_SOURCE="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
ROOT_DRIVE=""
if [[ -b "$ROOT_SOURCE" ]]; then
    ROOT_DRIVE="$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null | head -n1 | tr -d '[:space:]')"
    [[ -n "$ROOT_DRIVE" ]] && ROOT_DRIVE="/dev/$ROOT_DRIVE" || ROOT_DRIVE="$ROOT_SOURCE"
fi

# ── Enumerate USB disks only ─────────────────────────────────────────────────
info "Available USB disks:"
echo ""
printf "  ${MUTED}%-4s  %-14s  %-8s  %s${RESET}\n" "Sel" "Device" "Size" "Model"
printf "  ${MUTED}%-4s  %-14s  %-8s  %s${RESET}\n" "---" "------" "----" "-----"

declare -a USB_DRIVES=()
while read -r name size tran model; do
    [[ "$tran" == "usb" ]] || continue
    dev="/dev/$name"
    [[ "$dev" == "$ROOT_DRIVE" ]] && continue
    USB_DRIVES+=("$dev")
    printf "  ${ACCENT}[%-2d]${RESET}  ${BOLD}%-14s${RESET}  ${FG}%-8s${RESET}  ${MUTED}%s${RESET}\n" \
        "${#USB_DRIVES[@]}" "$dev" "$size" "${model:-Unknown}"
done < <(lsblk -dno NAME,SIZE,TRAN,MODEL 2>/dev/null)

echo ""
[[ ${#USB_DRIVES[@]} -gt 0 ]] \
    || err "No removable USB disks found. Insert a USB drive (internal disks are never listed)."

# ── Select device ───────────────────────────────────────────────────────────
echo -ne "${ACCENT}Select USB disk [1-${#USB_DRIVES[@]}]: ${RESET}"
read -r choice
[[ "$choice" =~ ^[0-9]+$ ]] || err "Invalid selection"
(( choice >= 1 && choice <= ${#USB_DRIVES[@]} )) || err "Invalid selection"

TARGET_DEV="${USB_DRIVES[$((choice - 1))]}"
TARGET_BYTES="$(blockdev --getsize64 "$TARGET_DEV" 2>/dev/null || echo 0)"
TARGET_SIZE="$(lsblk -dno SIZE "$TARGET_DEV" | tr -d '[:space:]')"

if (( TARGET_BYTES > 0 && TARGET_BYTES < ISO_BYTES )); then
    err "USB drive is too small: ISO is $ISO_SIZE, drive is $TARGET_SIZE"
fi

# ── Final confirmation ──────────────────────────────────────────────────────
echo ""
warn "This will overwrite $TARGET_DEV ($TARGET_SIZE) with $ISO_NAME."
echo -ne "${ACCENT}Type FLASH to continue: ${RESET}"
read -r confirmation
[[ "$confirmation" == "FLASH" ]] || err "Aborted"

info "Unmounting partitions on $TARGET_DEV..."
while IFS= read -r part; do
    [[ -n "$part" ]] || continue
    umount "/dev/$part" 2>/dev/null || true
done < <(lsblk -lno NAME "$TARGET_DEV" | tail -n +2)

echo ""
info "Writing to $TARGET_DEV -- do not remove the drive..."
echo ""
dd if="$ISO" of="$TARGET_DEV" bs=4M conv=fsync status=progress
sync

echo ""
ok "Flash complete. $TARGET_DEV is ready to boot Axyl Linux."
note "You can safely remove the drive."
