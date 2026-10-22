#!/usr/bin/env bash

iso_name="axyl-artix"
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
    ["/usr/local/bin/start-hyprland-session"]="0:0:755"
    ["/usr/local/bin/brave-wayland"]="0:0:755"
    ["/usr/local/bin/axyl-install"]="0:0:755"
    ["/usr/local/bin/axyl-setup"]="0:0:755"
    ["/usr/bin/pacstrap"]="0:0:755"
    ["/usr/bin/arch-chroot"]="0:0:755"
    ["/usr/bin/genfstab"]="0:0:755"
    ["/usr/lib/initcpio/hooks/archiso"]="0:0:755"
    ["/usr/lib/initcpio/hooks/archiso_loop_mnt"]="0:0:755"
    ["/usr/lib/initcpio/install/archiso"]="0:0:755"
    ["/usr/lib/initcpio/install/archiso_loop_mnt"]="0:0:755"
    ["/etc/skel/.local/bin/bt-default-sink.sh"]="0:0:755"
    ["/etc/skel/.local/bin/start-audio.sh"]="0:0:755"
    ["/etc/skel/.local/bin/timer"]="0:0:755"
    ["/etc/skel/.config/rofi/powermenu.sh"]="0:0:755"
    ["/etc/skel/.config/rofi/keybinds.sh"]="0:0:755"
    ["/etc/skel/.config/theme/render.py"]="0:0:755"
    ["/etc/skel/.config/theme/themes.py"]="0:0:755"
)
