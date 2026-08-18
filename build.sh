#!/usr/bin/env bash
# Usage:
#   sudo ./build.sh [arch]   — Arch + systemd  (must run as root)
#        ./build.sh artix    — Artix + runit   (uses Docker, no sudo needed)
set -euo pipefail

VARIANT="${1:-arch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/axyl-out"
DOCKER_IMAGE="axyl-artix-builder:latest"

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

info "Axyl Linux — build script (variant: $VARIANT)"
echo ""

# ── Variant preflight ─────────────────────────────────────────────────────────
case "$VARIANT" in
    arch)
        [[ $EUID -ne 0 ]] && err "arch build must run as root: sudo ./build.sh"
        command -v mkarchiso &>/dev/null \
            || err "'mkarchiso' not found — run: sudo ./setup.sh"
        PROFILE_DIR="$SCRIPT_DIR/archiso"
        ok "Preflight passed (arch / native)"
        echo ""
        ;;
    artix)
        command -v docker &>/dev/null \
            || err "'docker' not found — install it or run: sudo ./setup.sh"
        docker info &>/dev/null \
            || err "Docker daemon not running — start it: systemd: sudo systemctl start docker | runit: sudo sv up dockerd"

        # Always remove and rebuild the Docker builder image to pick up
        # any Dockerfile.artix changes since the last run.
        if docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
            info "Removing old builder image..."
            docker rmi "$DOCKER_IMAGE"
            echo ""
        fi
        info "Building Docker builder image..."
        echo ""
        docker build -t "$DOCKER_IMAGE" \
            -f "$SCRIPT_DIR/Dockerfile.artix" "$SCRIPT_DIR"
        echo ""
        ok "Builder image ready ($DOCKER_IMAGE)"
        echo ""

        # Merge archiso/ (base) + artixiso/ (overrides) into a temp directory.
        # Files in artixiso/ win over archiso/ where names collide.
        # The merged directory is bind-mounted read-only into the container.
        TMP_PROFILE="$(mktemp -d /tmp/axyl-artix-XXXXX)"
        trap 'rm -rf "$TMP_PROFILE"' EXIT
        cp -rT "$SCRIPT_DIR/archiso"  "$TMP_PROFILE"
        cp -rT "$SCRIPT_DIR/artixiso" "$TMP_PROFILE"
        PROFILE_DIR="$TMP_PROFILE"
        ok "Preflight passed (artix / docker)"
        echo ""
        ;;
    *)
        err "Unknown variant '$VARIANT'. Usage: $0 [arch|artix]"
        ;;
esac

# ── Prepare output directory ──────────────────────────────────────────────────
mkdir -p "$OUT_DIR"

# ── Build ─────────────────────────────────────────────────────────────────────
info "Building Axyl ISO ($VARIANT)..."
note "Profile : $PROFILE_DIR"
note "Output  : $OUT_DIR"
echo ""

case "$VARIANT" in
    arch)
        WORK_DIR="$SCRIPT_DIR/axyl-work"
        rm -rf "$WORK_DIR"
        mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
        ;;
    artix)
        # The work directory (loop mounts, squashfs) lives inside the container.
        # Only the finished ISO is written back to the host via the /out bind mount.
        docker run --rm --privileged \
            -v "$PROFILE_DIR:/profile:ro" \
            -v "$(realpath "$OUT_DIR"):/out" \
            "$DOCKER_IMAGE" \
            mkarchiso -v -w /tmp/axyl-work -o /out /profile
        ;;
esac

echo ""
ok "Build complete!"
echo ""
info "ISO location:"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null \
    || note "(no .iso found — check mkarchiso output above)"
echo ""
info "Test in QEMU (BIOS):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G -boot d"
echo ""
info "Test in QEMU (UEFI — requires edk2-ovmf):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G \\"
note "    -bios /usr/share/ovmf/x64/OVMF.fd"
