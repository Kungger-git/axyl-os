#!/usr/bin/env bash
#
# test.sh -- boot a built Axyl ISO in QEMU for visual testing.
#
# Examples:
#   ./test.sh                      # numbered menu of built ISOs
#   ./test.sh arch                 # newest axyl-out/arch/*.iso, BIOS, persistent disk
#   ./test.sh artix --uefi         # OVMF with per-VM NVRAM
#   ./test.sh arch --snapshot      # throw away disk writes
#   ./test.sh arch --boot disk     # skip the ISO, boot the installed system
#   ./test.sh arch --share ~/Pictures
#
# Run ./test.sh --help for every option.

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUN_DIR=${AXYL_QEMU_DIR:-$HOME/axyl-qemu}
OVMF_DIR=${OVMF_DIR:-/usr/share/edk2/x64}
VIRTIOFSD=${VIRTIOFSD:-/usr/lib/virtiofsd}

VARIANT=
ISO=
UEFI=0
DISK_MODE=default        # default | none | path
DISK_PATH=
DISK=
SNAPSHOT=0
BOOT=iso                 # iso | disk
MEM=3072
CPUS=2
SOUND=1
SHARE=
GL=0
HEADLESS=0
VERIFY=0
DRY_RUN=0

TMP_VM=
VFS_PID=
QMP_SOCK=

warn() { printf '\033[33mWARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mERR \033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==> \033[0m%s\n' "$*"; }

cleanup() {
    [[ -n $VFS_PID ]] && kill "$VFS_PID" 2>/dev/null || true
    [[ -n $QMP_SOCK ]] && rm -f "$QMP_SOCK" || true
    [[ -n $TMP_VM ]] && rm -rf "$TMP_VM" || true
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: ./test.sh [VARIANT|ISO] [options]

VARIANT is "arch", "artix", or a path to an .iso. With no argument a numbered
menu of every ISO under axyl-out/ is shown.

Firmware
  --uefi              boot with OVMF (default: SeaBIOS)
  --bios              force SeaBIOS

Disk
  --disk none         live session only, no disk attached
  --disk PATH         use PATH instead of the per-variant default
  --snapshot          discard all disk writes when QEMU exits

Boot
  --boot iso          boot the ISO (default)
  --boot disk         boot the installed system on the disk, no ISO attached

Resources
  --mem MB            guest RAM in MiB (default 3072)
  --cpus N            vCPU count (default 2)

Devices
  --no-sound          disable the emulated HDA + PipeWire backend
  --share DIR         expose DIR to the guest at /mnt/share via virtiofs
  --gl                virtio-vga + GTK OpenGL (needs qemu-hw-display-virtio-vga)
  --headless          no window; drive the VM through QMP (screendump, keys)

Other
  --verify            check the ISO against its .sha256 first
  --dry-run           print the QEMU command and exit
  -h, --help          this text

The default disk is ~/axyl-qemu/<variant>-<firmware>.qcow2, created on first
use. The QMP socket is ~/axyl-qemu/qmp-<variant>-<firmware>.sock, so the QMP
helper in that directory can take screenshots:

  python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock shot shot.ppm

Keys: Ctrl+Alt+G releases the mouse, Ctrl+Alt+F toggles fullscreen.
After installing, close the VM and rerun with --boot disk.
EOF
}

# ---------------------------------------------------------------- arguments
while (($#)); do
    case $1 in
        --uefi)     UEFI=1 ;;
        --bios)     UEFI=0 ;;
        --disk)     shift; [[ -n ${1:-} ]] || die "--disk needs an argument"
                    if [[ $1 == none ]]; then DISK_MODE=none; else DISK_MODE=path; DISK_PATH=$1; fi ;;
        --snapshot) SNAPSHOT=1 ;;
        --boot)     shift; BOOT=${1:-}; [[ $BOOT == iso || $BOOT == disk ]] || die "--boot must be iso or disk" ;;
        --mem)      shift; MEM=${1:-} ;;
        --cpus)     shift; CPUS=${1:-} ;;
        --sound)    SOUND=1 ;;
        --no-sound) SOUND=0 ;;
        --share)    shift; SHARE=${1:-}; [[ -n $SHARE ]] || die "--share needs a directory" ;;
        --gl)       GL=1 ;;
        --headless) HEADLESS=1 ;;
        --verify)   VERIFY=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; break ;;
        -*)         die "unknown option: $1 (try --help)" ;;
        *)          if [[ -z $VARIANT ]]; then VARIANT=$1; else die "unexpected argument: $1"; fi ;;
    esac
    shift
done

[[ $MEM  =~ ^[0-9]+$ ]] && ((MEM  >= 512)) || die "--mem must be an integer >= 512"
[[ $CPUS =~ ^[0-9]+$ ]] && ((CPUS >= 1))   || die "--cpus must be an integer >= 1"

# ---------------------------------------------------------------- locate ISO
if [[ -n $VARIANT && -f $VARIANT ]]; then
    ISO=$VARIANT
elif [[ -n $VARIANT ]]; then
    case $VARIANT in
        arch|artix) iso_dir=$REPO_DIR/axyl-out/$VARIANT ;;
        *) die "no such ISO: $VARIANT" ;;
    esac
    newest=$(find "$iso_dir" -maxdepth 1 -name '*.iso' -printf '%f\n' 2>/dev/null | sort -V | tail -1)
    [[ -n $newest ]] || die "no ISO in $iso_dir -- run ./build.sh $VARIANT first"
    ISO=$iso_dir/$newest
else
    mapfile -t isos < <(find "$REPO_DIR/axyl-out" -mindepth 2 -maxdepth 2 -name '*.iso' 2>/dev/null | sort -V)
    ((${#isos[@]})) || die "no ISOs under $REPO_DIR/axyl-out -- run ./build.sh arch|artix first"
    if ((${#isos[@]} == 1)); then
        ISO=${isos[0]}
    else
        PS3='Select an ISO: '
        select choice in "${isos[@]}"; do
            [[ -n ${choice:-} ]] && { ISO=$choice; break; }
        done
        [[ -n $ISO ]] || die "no ISO selected"
    fi
fi

ISO=$(cd -- "$(dirname -- "$ISO")" && pwd)/$(basename -- "$ISO")
[[ -f $ISO ]] || die "ISO not found: $ISO"

case $(basename -- "$ISO") in
    axyl-artix-*) VARIANT=artix ;;
    axyl-arch-*)  VARIANT=arch ;;
    *)            VARIANT=$(basename -- "$(dirname -- "$ISO")") ;;
esac
FW=$([[ $UEFI == 1 ]] && echo uefi || echo bios)

# ---------------------------------------------------------------- disk
if [[ $DISK_MODE == none ]]; then
    [[ $BOOT != disk ]] || die "--boot disk cannot be combined with --disk none"
    DISK=
else
    if [[ $DISK_MODE == path ]]; then
        DISK=$DISK_PATH
        DISK_EXPLICIT=1
    else
        DISK=$RUN_DIR/axyl-$VARIANT-$FW.qcow2
        DISK_EXPLICIT=0
    fi

    if [[ $BOOT == disk && ! -f $DISK ]]; then
        die "no installed system at $DISK -- boot the ISO first and install"
    fi

    if [[ ! -f $DISK && $DRY_RUN == 0 ]]; then
        command -v qemu-img >/dev/null || die "qemu-img is missing (pacman -S qemu-img)"
        mkdir -p -- "$(dirname -- "$DISK")"
        info "Creating 20G test disk $DISK"
        qemu-img create -q -f qcow2 "$DISK" 20G
    fi
fi

# ---------------------------------------------------------------- preflight
if [[ $DRY_RUN == 0 ]]; then
    command -v qemu-system-x86_64 >/dev/null ||
        die "qemu-system-x86_64 is missing (pacman -S qemu-system-x86)"

    missing=()
    qemu-system-x86_64 -display help 2>/dev/null | grep -qx gtk ||
        missing+=(qemu-ui-gtk)
    if ((SOUND)); then
        qemu-system-x86_64 -audiodev help 2>/dev/null | grep -qx pipewire ||
            missing+=(qemu-audio-pipewire)
    fi
    if ((GL)); then
        qemu-system-x86_64 -device help 2>/dev/null | grep -q 'name "virtio-vga"' ||
            missing+=(qemu-hw-display-virtio-vga qemu-ui-opengl)
    fi
    if [[ -n $SHARE ]]; then
        [[ -x $VIRTIOFSD ]] || missing+=(virtiofsd)
    fi
    if ((UEFI)); then
        [[ -f $OVMF_DIR/OVMF_CODE.4m.fd && -f $OVMF_DIR/OVMF_VARS.4m.fd ]] ||
            missing+=(edk2-ovmf)
    fi

    if ((${#missing[@]})); then
        printf '\033[31mERR \033[0mMissing QEMU components for this configuration.\n' >&2
        printf '\n  sudo pacman -S --needed %s\n\n' "${missing[*]}" >&2
        exit 1
    fi
fi

if ((UEFI)); then
    OVMF_CODE=$OVMF_DIR/OVMF_CODE.4m.fd
    OVMF_VARS=$OVMF_DIR/OVMF_VARS.4m.fd
    VARS=$RUN_DIR/edk2-vars-$VARIANT.fd
    if [[ ! -f $VARS && $DRY_RUN == 0 ]]; then
        mkdir -p -- "$RUN_DIR"
        cp -- "$OVMF_VARS" "$VARS"
        info "Created persistent NVRAM $VARS"
    fi
fi

# ---------------------------------------------------------------- checksum
if ((VERIFY)); then
    sha=$ISO.sha256
    [[ -f $sha ]] || die "checksum file not found: $sha"
    info "Verifying $(basename -- "$ISO")"
    ( cd -- "$(dirname -- "$ISO")" && sha256sum -c -- "$(basename -- "$sha")" ) ||
        die "ISO checksum mismatch"
fi

# ---------------------------------------------------------------- accel
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL=kvm
    CPU=host
else
    ACCEL=tcg
    CPU=max
    warn "/dev/kvm is not accessible; falling back to slow TCG emulation"
fi

# ---------------------------------------------------------------- virtiofs
if [[ -n $SHARE ]]; then
    [[ -d $SHARE ]] || die "share directory not found: $SHARE"
    SHARE=$(cd -- "$SHARE" && pwd)
    if [[ $DRY_RUN == 1 ]]; then
        VFS_SOCK=/tmp/axyl-vm-DRYRUN/virtiofs.sock
    else
        TMP_VM=$(mktemp -d "${TMPDIR:-/tmp}/axyl-vm.XXXXXX")
        VFS_SOCK=$TMP_VM/virtiofs.sock
        "$VIRTIOFSD" --shared-dir "$SHARE" --socket-path "$VFS_SOCK" \
            --sandbox none --cache auto >"$TMP_VM/virtiofsd.log" 2>&1 &
        VFS_PID=$!
        for _ in {1..50}; do [[ -S $VFS_SOCK ]] && break; sleep 0.1; done
        if [[ ! -S $VFS_SOCK ]]; then
            cat -- "$TMP_VM/virtiofsd.log" >&2 || true
            die "virtiofsd failed to start"
        fi
    fi
fi

# ---------------------------------------------------------------- qemu cmd
MACHINE="q35,accel=$ACCEL"
if [[ -n $SHARE ]]; then
    MACHINE+=",memory-backend=mem0"
fi

CMD=(qemu-system-x86_64
    -machine "$MACHINE"
    -cpu "$CPU"
    -smp "$CPUS"
    -m "$MEM"
    -name "Axyl $VARIANT ($FW)"
    -rtc base=localtime,clock=host
)

if ((HEADLESS)); then
    CMD+=(-display none)
elif ((GL)); then
    CMD+=(-display gtk,gl=on,zoom-to-fit=on,show-cursor=on -vga virtio)
else
    CMD+=(-display gtk,zoom-to-fit=on,show-cursor=on)
fi

CMD+=(-device qemu-xhci -device usb-tablet)

if ((SOUND)); then
    CMD+=(-audiodev pipewire,id=snd0
          -device ich9-intel-hda
          -device hda-duplex,audiodev=snd0)
fi

CMD+=(-nic user,model=virtio-net-pci)

if [[ -n $SHARE ]]; then
    CMD+=(-object "memory-backend-memfd,id=mem0,size=${MEM}M,share=on"
          -chardev "socket,id=vfs0,path=$VFS_SOCK"
          -device "vhost-user-fs-pci,chardev=vfs0,tag=share")
fi

if [[ -n $DISK ]]; then
    CMD+=(-drive "file=$DISK,if=virtio,format=qcow2")
fi
if ((SNAPSHOT)); then
    CMD+=(-snapshot)
fi

if [[ $BOOT == iso ]]; then
    CMD+=(-cdrom "$ISO")
    if [[ -n $DISK ]]; then
        CMD+=(-boot order=c,once=d,menu=on)   # ISO now, installed disk after reboot
    else
        CMD+=(-boot order=d,menu=on)
    fi
else
    CMD+=(-boot order=c,menu=on)
fi

if ((UEFI)); then
    CMD+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
          -drive "if=pflash,format=raw,file=$VARS")
fi

QMP_SOCK=$RUN_DIR/qmp-$VARIANT-$FW.sock
if [[ $DRY_RUN == 0 ]]; then
    mkdir -p -- "$RUN_DIR"
    install -m 0755 -- "$REPO_DIR/tools/qmp.py" "$RUN_DIR/qmp.py"
    rm -f -- "$QMP_SOCK"
fi
CMD+=(-qmp "unix:$QMP_SOCK,server=on,wait=off")

# ---------------------------------------------------------------- summary
printf '\n'
printf '  ISO      : %s\n' "$ISO"
printf '  Firmware : %s\n' "$FW"
if [[ -n $DISK ]]; then
    printf '  Disk     : %s%s\n' "$DISK" "$([[ $SNAPSHOT == 1 ]] && echo ' (snapshot)')"
else
    printf '  Disk     : none (live only)\n'
fi
printf '  Boot     : %s\n' "$BOOT"
printf '  Memory   : %s MiB, %s vCPU, accel %s\n' "$MEM" "$CPUS" "$ACCEL"
if ((HEADLESS)); then display_desc='headless (QMP screendump)'
elif ((GL)); then display_desc='GTK window (OpenGL)'
else display_desc='GTK window'
fi
printf '  Display  : %s\n' "$display_desc"
printf '  Audio    : %s\n' "$([[ $SOUND == 1 ]] && echo 'HDA -> PipeWire' || echo off)"
if [[ -n $SHARE ]]; then
    printf '  Share    : %s -> /mnt/share\n' "$SHARE"
    printf '             guest: sudo mount -t virtiofs share /mnt/share\n'
fi
printf '  QMP      : %s\n' "$QMP_SOCK"
if ((HEADLESS)); then
    printf '\n  Headless: drive the VM with the QMP socket (screendump, send-key, quit).\n'
else
    printf '\n  Keys: Ctrl+Alt+G releases the mouse; Ctrl+Alt+F toggles fullscreen.\n'
fi
if [[ $BOOT == iso ]]; then
    printf '  After installing, close the VM and rerun with --boot disk.\n'
fi
printf '\n'

if ((DRY_RUN)); then
    printf '%q ' "${CMD[@]}"
    printf '\n'
    exit 0
fi

"${CMD[@]}"
