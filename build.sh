#!/usr/bin/env bash
# Usage: sudo ./build.sh [arch|artix]   (default: arch)
set -euo pipefail

VARIANT="${1:-arch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/axyl-work"
OUT_DIR="$SCRIPT_DIR/axyl-out"

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

# ── Variant selection ─────────────────────────────────────────────────────────
case "$VARIANT" in
    arch)
        PROFILE_DIR="$SCRIPT_DIR/archiso"
        ;;
    artix)
        # Merge archiso (base) + artixiso (overrides) into a temp profile.
        # Files present in artixiso/ win over archiso/ equivalents.
        # Build host must be an Artix Linux system with artix-archiso installed.
        TMP_PROFILE="$(mktemp -d /tmp/axyl-artix-XXXXX)"
        trap 'rm -rf "$TMP_PROFILE"' EXIT
        cp -rT "$SCRIPT_DIR/archiso"   "$TMP_PROFILE"
        cp -rT "$SCRIPT_DIR/artixiso"  "$TMP_PROFILE"
        PROFILE_DIR="$TMP_PROFILE"
        ;;
    *)
        err "Unknown variant '$VARIANT'. Usage: $0 [arch|artix]"
        ;;
esac

info "Axyl Linux — build script (variant: $VARIANT)"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root: sudo ./build.sh $VARIANT"

for cmd in mkarchiso git; do
    command -v "$cmd" &>/dev/null \
        || err "'$cmd' not found. Run: sudo ./setup.sh"
done

ok "Preflight checks passed"
echo ""

# ── Clean build directories ───────────────────────────────────────────────────
info "Cleaning build directories..."
rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"
ok "Build directories ready"
echo ""

# ── Build ─────────────────────────────────────────────────────────────────────
info "Building Axyl ISO ($VARIANT)..."
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
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G -boot d"
echo ""
info "Test in QEMU (UEFI — requires edk2-ovmf):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G \\"
note "    -bios /usr/share/ovmf/x64/OVMF.fd"
