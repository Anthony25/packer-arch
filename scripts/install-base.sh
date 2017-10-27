#!/usr/bin/env bash

# stop on errors
set -eu

if [[ $PACKER_BUILDER_TYPE == "qemu" ]]; then
	DISK='/dev/vda'
else
	DISK='/dev/sda'
fi

ROOT_PARTITION="${DISK}1"
TARGET_DIR='/mnt'
CONF_DIR="/home/packer/conf"


install_os() {
    partition_disk
    format_first_partition_in_ext
    mount_root_partition

    setup_live_mirrorlist
    install_pkg
    enable_systemd_services
    disable_predictable_interfaces
    enable_dhcp_on_eth0
    add_ssh_keys

    setup_syslinux
    build_kernel_img
    clean_up
}

partition_disk() {
    echo "==> Clearing partition table on ${DISK}"
    sgdisk --zap ${DISK}

    echo "==> Destroying magic strings and signatures on ${DISK}"
    dd if=/dev/zero of=${DISK} bs=512 count=2048
    wipefs --all ${DISK}

    echo "==> Creating /root partition on ${DISK}"
    sgdisk --new=1:0:0 ${DISK}

    echo "==> Setting ${DISK} bootable"
    sgdisk ${DISK} --attributes=1:set:2
}

format_first_partition_in_ext() {
    echo '==> Creating /root filesystem (ext4)'
    mkfs.ext4 -O '^64bit' -F -q -L root ${ROOT_PARTITION}
}

mount_root_partition() {
    echo "==> Mounting ${ROOT_PARTITION} to ${TARGET_DIR}"
    mount -o noatime,errors=remount-ro ${ROOT_PARTITION} ${TARGET_DIR}
}

setup_live_mirrorlist() {
    if [ -n "${MIRRORLIST}" ]; then
        echo '==> Setup live mirrorlist'
        echo "${MIRRORLIST}" > /etc/pacman.d/mirrorlist
    fi
}

install_pkg() {
    echo '==> Install packages'
    pacstrap ${TARGET_DIR} base base-devel

    /usr/bin/arch-chroot ${TARGET_DIR} \
        pacman -S --noconfirm gptfdisk openssh syslinux python2 haveged
    install -o root -g root -m 644 {,"${TARGET_DIR}"}/etc/pacman.d/mirrorlist
}

enable_systemd_services() {
    echo '==> Enable needed systemd services'

    arch-chroot "${TARGET_DIR}" \
        systemctl enable sshd systemd-networkd systemd-resolved haveged \
            getty@ttyS0
}

disable_predictable_interfaces() {
    echo '==> Disable predictable interfaces'

	ln -s /dev/null "${TARGET_DIR}"/etc/udev/rules.d/80-net-setup-link.rules
}

enable_dhcp_on_eth0() {
    SYSTEMD_NETWORKD_PROFILE=$(echo \
        $'[Match]' \
        $'\nName=eth0' \
        $'\n' \
        $'\n[Network]' \
        $'\nDHCP=yes' \
    )

    if [ -n "${IP4}" ]; then
        SYSTEMD_NETWORKD_PROFILE+=$'\n'"ADDRESS=${IP4}"
    fi

    if [ -n "${IP6}" ]; then
        SYSTEMD_NETWORKD_PROFILE+=$'\n'"ADDRESS=${IP6}"
    fi

    echo "${SYSTEMD_NETWORKD_PROFILE}" > \
        "${TARGET_DIR}/etc/systemd/network/eth0.network"
    rm "${TARGET_DIR}"/etc/resolv.conf
    ln -s /run/systemd/resolve/resolv.conf "${TARGET_DIR}"/etc/resolv.conf
}

add_ssh_keys() {
    echo '==> Add SSH keys'

    mkdir -p "${TARGET_DIR}/root/.ssh"
    chmod 700 "${TARGET_DIR}/root/.ssh"
    echo "${AUTHORIZED_KEYS}" >> "${TARGET_DIR}/root/.ssh/authorized_keys"
    chmod 600 "${TARGET_DIR}/root/.ssh/authorized_keys"
}

setup_syslinux() {
    echo '==> Setup and configures Syslinux'

    /usr/bin/arch-chroot ${TARGET_DIR} syslinux-install_update -i -a -m
    /usr/bin/sed -i \
        "s|sda3|${ROOT_PARTITION##/dev/}|" \
        "${TARGET_DIR}/boot/syslinux/syslinux.cfg"
    /usr/bin/sed -i \
        's/TIMEOUT 50/TIMEOUT 10/' \
        "${TARGET_DIR}/boot/syslinux/syslinux.cfg"
}

build_kernel_img() {
    echo '==> Build kernel'

    cp "$CONF_DIR"/mkinitcpio.conf "${TARGET_DIR}"/etc/mkinitcpio.conf
    chmod 644 "${TARGET_DIR}"/etc/mkinitcpio.conf

    arch-chroot "${TARGET_DIR}" mkinitcpio -p linux
}

clean_up() {
    echo '==> Clean Up'

	arch-chroot "${TARGET_DIR}" pacman -Rcns --noconfirm gptfdisk
	arch-chroot "${TARGET_DIR}" pacman -Scc --noconfirm
	arch-chroot "${TARGET_DIR}" pacman-optimize

    zerofile=$(mktemp "${TARGET_DIR}"/zerofile.XXXXX)
    dd if=/dev/zero of="$zerofile" bs=1M || true
    rm -f "$zerofile"
    sync
}


install_os

echo '==> Installation complete!'
/usr/bin/sleep 3
/usr/bin/umount ${TARGET_DIR}
