#!/usr/bin/env bash
# Usage:
#   ./build.sh [arch]   -- Arch + systemd  (Docker)
#   ./build.sh artix    -- Artix + runit   (Docker)
set -euo pipefail

# Use BuildKit if buildx is available; otherwise fall back to the legacy builder.
docker buildx version &>/dev/null && export DOCKER_BUILDKIT=1 || true

VARIANT="${1:-arch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/axyl-out"

# Colours
ACCENT='\e[38;2;217;119;87m'
GREEN='\e[38;2;80;250;123m'
RED='\e[38;2;255;85;85m'
MUTED='\e[38;2;110;114;144m'
RESET='\e[0m'

info() { echo -e "${ACCENT}==> ${RESET}$*"; }
ok()   { echo -e "${GREEN} ok ${RESET}$*"; }
err()  { echo -e "${RED}ERR ${RESET}$*" >&2; exit 1; }
note() { echo -e "${MUTED}    $*${RESET}"; }

info "Axyl Linux -- build script (variant: $VARIANT)"
echo ""

# Variant preflight
case "$VARIANT" in
    arch)
        command -v docker &>/dev/null \
            || err "'docker' not found -- install Docker first"
        docker info &>/dev/null \
            || err "Docker daemon not running -- start it: sudo systemctl start docker"

        DOCKER_IMAGE="axyl-arch-builder:latest"
        DOCKERFILE="$SCRIPT_DIR/docker/Dockerfile.arch"

        TMP_PROFILE="$(mktemp -d /tmp/axyl-arch-XXXXX)"
        trap 'rm -rf "$TMP_PROFILE"' EXIT
        cp -rT "$SCRIPT_DIR/archiso" "$TMP_PROFILE"
        ;;
    artix)
        command -v docker &>/dev/null \
            || err "'docker' not found -- install Docker first"
        docker info &>/dev/null \
            || err "Docker daemon not running -- start it: systemd: sudo systemctl start docker | runit: sudo sv up dockerd"

        DOCKER_IMAGE="axyl-artix-builder:latest"
        DOCKERFILE="$SCRIPT_DIR/docker/Dockerfile.artix"

        TMP_PROFILE="$(mktemp -d /tmp/axyl-artix-XXXXX)"
        trap 'rm -rf "$TMP_PROFILE"' EXIT
        cp -rT "$SCRIPT_DIR/archiso"  "$TMP_PROFILE"
        cp -rT "$SCRIPT_DIR/artixiso" "$TMP_PROFILE"
        ;;
    *)
        err "Unknown variant '$VARIANT'. Usage: $0 [arch|artix]"
        ;;
esac

# Inject the shared skel into the assembled profile.
# skel/ lives at the repo root -- not inside archiso/ or artixiso/ -- so it is
# variant-neutral and not subject to the override layer merge.
cp -rT "$SCRIPT_DIR/skel" "$TMP_PROFILE/airootfs/etc/skel"
PROFILE_DIR="$TMP_PROFILE"

# Build Docker builder image.
# Always remove and rebuild to pick up any Dockerfile changes since the last run.
if docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
    info "Removing old builder image..."
    docker rmi "$DOCKER_IMAGE"
    echo ""
fi
info "Building Docker builder image..."
echo ""
docker build -t "$DOCKER_IMAGE" - < "$DOCKERFILE"
echo ""
ok "Builder image ready ($DOCKER_IMAGE)"
ok "Preflight passed ($VARIANT / docker)"
echo ""

# Prepare output directory
mkdir -p "$OUT_DIR"

# Build
info "Building Axyl ISO ($VARIANT)..."
note "Profile : $PROFILE_DIR"
note "Output  : $OUT_DIR"
echo ""

docker run --rm --privileged \
    -v "$PROFILE_DIR:/profile:ro" \
    -v "$(realpath "$OUT_DIR"):/out" \
    "$DOCKER_IMAGE" \
    mkarchiso -v -w /tmp/axyl-work -o /out /profile

echo ""
ok "Build complete!"
echo ""
info "ISO location:"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null \
    || note "(no .iso found -- check mkarchiso output above)"
echo ""
info "Test in QEMU (BIOS):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G -boot d"
echo ""
info "Test in QEMU (UEFI -- requires edk2-ovmf):"
note "  qemu-system-x86_64 -cdrom $OUT_DIR/*.iso -m 2G \\"
note "    -bios /usr/share/ovmf/x64/OVMF.fd"
