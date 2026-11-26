#!/bin/sh
# Reassemble a split Axyl ISO and verify its checksum.
set -eu

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "usage: $0 <iso-name> [directory]" >&2
    exit 2
fi

name=$1
dir=${2:-.}
iso="$dir/$name"

if [ ! -f "$iso.sha256" ]; then
    echo "missing $iso.sha256" >&2
    exit 1
fi
if ! ls "$iso".part-* >/dev/null 2>&1; then
    echo "no $name.part-* files in $dir" >&2
    exit 1
fi

cat "$iso".part-* > "$iso"
( cd "$dir" && sha256sum -c "$name.sha256" )
echo "OK: $iso"
