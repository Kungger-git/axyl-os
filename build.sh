#!/usr/bin/env bash
# Usage:
#   ./build.sh [arch]   -- Arch + systemd  (Docker)
#   ./build.sh artix    -- Artix + runit   (Docker)
set -euo pipefail

# Use BuildKit if buildx is available; otherwise fall back to the legacy builder.
docker buildx version &>/dev/null && export DOCKER_BUILDKIT=1 || true

VARIANT="${1:-arch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_ROOT="$SCRIPT_DIR/axyl-out"
ISO_DIR="$OUT_ROOT/$VARIANT"
PKG_DIR="$SCRIPT_DIR/axyl-build/pkgs"
VERSION="$(date +%Y.%m.%d)"

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

info "Axyl Linux -- build script (variant: $VARIANT, version: $VERSION)"
echo ""

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

# Shared desktop/user configuration.
cp -rT "$SCRIPT_DIR/skel" "$TMP_PROFILE/airootfs/etc/skel"

# Build the vendored Brave package once.  Brave is AUR-only, so the ISO never
# depends on AUR access; the built package is installed from the live image and
# copied into the installed system by axyl-install.
mkdir -p "$PKG_DIR"
if ! compgen -G "$PKG_DIR/brave-bin-*.pkg.tar.zst" >/dev/null; then
    info "Building vendored brave-bin package (first run only)..."
    echo ""
    docker build -t axyl-brave-builder:latest - < "$SCRIPT_DIR/docker/Dockerfile.brave"
    docker run --rm -v "$PKG_DIR:/out" axyl-brave-builder:latest \
        sh -c 'cp /home/builder/out/brave-bin-*.pkg.tar.zst /out/'
    ok "Brave package built"
    echo ""
fi
BRAVE_PKG="$(find "$PKG_DIR" -maxdepth 1 -name 'brave-bin-*.pkg.tar.zst' | sort | tail -n1)"
[[ -n "$BRAVE_PKG" ]] || err "Could not locate built brave-bin package"
note "Brave package: $(basename "$BRAVE_PKG")"
mkdir -p "$TMP_PROFILE/airootfs/usr/local/share/axyl"
cp "$BRAVE_PKG" "$TMP_PROFILE/airootfs/usr/local/share/axyl/"

# Build Docker builder image.
if docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
    info "Removing old builder image..."
    docker rmi "$DOCKER_IMAGE"
    echo ""
fi
info "Building Docker builder image..."
echo ""
docker build --pull --no-cache -t "$DOCKER_IMAGE" - < "$DOCKERFILE"
echo ""
ok "Builder image ready ($DOCKER_IMAGE)"
ok "Preflight passed ($VARIANT / docker)"
echo ""

# The output root is root-owned from previous builds; let the container create
# the per-variant directory and write the ISO/checksums.
mkdir -p "$OUT_ROOT" 2>/dev/null || true
docker run --rm -v "$OUT_ROOT:/out" "$DOCKER_IMAGE" \
    sh -c "mkdir -p '/out/$VARIANT'"
docker run --rm -v "$ISO_DIR:/out" "$DOCKER_IMAGE" \
    sh -c 'rm -f /out/*.iso /out/*.sha256 /out/*manifest*'

info "Building Axyl ISO ($VARIANT)..."
note "Profile : $TMP_PROFILE"
note "Output  : $ISO_DIR"
echo ""

docker run --rm --privileged \
    -v "$TMP_PROFILE:/profile:ro" \
    -v "$ISO_DIR:/out" \
    "$DOCKER_IMAGE" \
    mkarchiso -v -w /tmp/axyl-work -o /out /profile

echo ""
info "Writing checksums and manifest..."
docker run --rm -v "$ISO_DIR:/out" \
    -e AXYL_VARIANT="$VARIANT" -e AXYL_VERSION="$VERSION" \
    "$DOCKER_IMAGE" sh -c '
        set -eu
        cd /out
        iso="$(find . -maxdepth 1 -name "axyl-${AXYL_VARIANT}-*-x86_64.iso" -printf "%f\n" | sort | tail -n1)"
        [ -n "$iso" ] || { echo "ISO not found" >&2; exit 1; }
        sha256sum "$iso" > "$iso.sha256"
        {
            echo "variant=${AXYL_VARIANT}"
            echo "version=${AXYL_VERSION}"
            echo "iso=${iso}"
            echo "sha256=$(cut -d" " -f1 "$iso.sha256")"
            echo "built_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "profile=axyl-${AXYL_VARIANT}"
        } > "axyl-${AXYL_VARIANT}-manifest.txt"
    '

echo ""
ok "Build complete!"
echo ""
info "ISO location:"
ls -lh "$ISO_DIR"/*.iso 2>/dev/null \
    || note "(no .iso found -- check mkarchiso output above)"
ls -lh "$ISO_DIR"/*.sha256 "$ISO_DIR"/*manifest* 2>/dev/null || true
echo ""
info "Test in QEMU (BIOS):"
note "  qemu-system-x86_64 -cdrom $ISO_DIR/*.iso -m 2G -boot d"
echo ""
info "Test in QEMU (UEFI -- requires edk2-ovmf):"
note "  qemu-system-x86_64 -cdrom $ISO_DIR/*.iso -m 2G \\"
note "    -bios /usr/share/ovmf/x64/OVMF.fd"
