#!/usr/bin/bash

echo "sda or nvme?"
echo "create 3 partitions: first one is efi, second is swap, third is root"
echo "dont forget to select correct type. for first one, select fat32. for second, select swap. for third, select linit filesystem"
read output
bloat="xfsprogs btrfs-progs ipw2100-firmware ipw2200-firmware zd1211-firmware linux-firmware-amd linux-firmware-broadcom base-container-full"
needed="libusb usbutils dbus connman acpi acpid cpio libaio device-mapper kpartx dracut linux-firmware-network linux6.11 linux6.11-headers"
installcommand="chroot /mnt /bin/sh -c"

fornvme() {
    ## get disk name
    device="/dev/nvme0n1"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    cfdisk $device

    ## format disk
    mkfs.vfat -F32 ${device}p1
    mkswap ${device}p2
    mkfs.ext4 ${device}p3

    ## mount disk
    mount ${device}p3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${device}p1 /mnt/boot/efi
    swapon ${device}p2

    ## download tarball
    downloadtarball

    ## enter chroot
    mountfilesandchroot

    ## install system
    installsystem

    ##setup repo
    setuprepo

    ## prepare system
    prepare
}

forsda() {
    ## get disk name
    device="/dev/sda"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    #rm -rf /mnt/*
    cfdisk $device
    
    ## format disk
    #mkfs.vfat -F32 ${device}1
    #mkswap ${device}2
    #mkfs.ext4 ${device}3

    ## mount disk
    mount ${device}3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${device}1 /mnt/boot/efi
    swapon ${device}2

    ## download tarball
    #downloadtarball

    ## enter chroot
    mountfilesandchroot

    ##setup repo
    setuprepo

    ## install system
    installsystem

    ## prepare system
    #prepare
}

downloadtarball() {
    echo "downloading tarball"
    wget -O /tmp/void.tar.xz https://repo-fastly.voidlinux.org/live/current/void-x86_64-ROOTFS-20240314.tar.xz
    tar -xvf /tmp/void.tar.xz -C /mnt
}

mountfilesandchroot() {
    echo "mounting"
    mount -t proc none /mnt/proc
    mount -t sysfs none /mnt/sys
    mount --rbind /mnt/dev /mnt/dev
    mount --rbind /mnt/run /mnt/run
}

setuprepo() {
    echo "fastest repos installing"
    rm /mnt/usr/share/xbps.d/00-repository-main.conf
    touch /mnt/usr/share/xbps.d/00-repository.conf
    # Append new repository URLs using echo
    echo 'repository=https://repo-fastly.voidlinux.org/current' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-fastly.voidlinux.org/current/nonfree' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-fastly.voidlinux.org/current/multilib' >> /mnt/usr/share/xbps.d/00-repository-main.conf
}


installsystem() {
    sed -i '$a'
    echo "installing system"
    #$installcommand "xbps-install -Su xbps"
    #$installcommand "xbps-install -u"
    $installcommand "xbps-install $needed"
    $installcommand "xbps-remove $bloat"
}

prepare() {
    echo "preparing system, better get ready"
    $installcommand "nvi /etc/hostname"
    #$installcommand "nvi /etc/rc.conf"
    #$installcommand "nvi /etc/default/libc-locales"
    #$installcommand "xbps-reconfigure -f glibc-locales"
}

if [ "$output" == "sda" ]; then
   forsda
elif [ "$output" == "nvme" ]; then
    fornvme
else
    echo "nuh uh"
fi

