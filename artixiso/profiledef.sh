#!/usr/bin/env bash

iso_name="axyl"
iso_label="AXYL_ARTIX_$(date +%Y%m)"
iso_publisher="Axyl Linux"
iso_application="Axyl Linux Live/Install CD (Artix / runit)"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi-x64.grub.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '512K')

declare -A file_permissions=(
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/etc/skel/.xinitrc"]="0:0:755"
    ["/etc/skel/.config/bspwm/bspwmrc"]="0:0:755"
    ["/etc/skel/.config/polybar/launch.sh"]="0:0:755"
    ["/usr/local/bin/start-bspwm-session"]="0:0:755"
    ["/usr/local/bin/axyl-install"]="0:0:755"
    ["/usr/local/bin/axyl-setup"]="0:0:755"
    ["/usr/local/bin/axyl-powermenu"]="0:0:755"
    ["/usr/local/bin/axyl-lock"]="0:0:755"
    ["/usr/local/bin/axyl-osd-volume"]="0:0:755"
    ["/usr/local/bin/axyl-osd-brightness"]="0:0:755"
)