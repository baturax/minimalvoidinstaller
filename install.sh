#!/usr/bin/bash

echo "make sure xz vim and wget is installed"

echo "sda or nvme?"
echo "create 3 partitions: first one is efi, second is swap, third is root"
echo "dont forget to select correct type. for first one, select fat32. for second, select swap. for third, select linux filesystem"
read output

bloat="sudo xfsprogs btrfs-progs ipw2100-firmware ipw2200-firmware zd1211-firmware linux-firmware-amd linux-firmware-broadcom base-container-full"

needed="opendoas neovim libusb usbutils dbus connman bash-completion acpi acpid cpio libaio device-mapper sof-firmware kpartx dracut linux-firmware-network linux6.12 linux6.12-headers sof-firmware git"

installcommand="chroot /mnt /bin/sh -c"
FSTAB_FILE="/etc/fstab"

neededbloat="opendoas xdg-utils git curl wget nvidia  alsa-lib alsa-firmware alsa-tools alsa-utils playerctl chrony "

askbloats="Wanna install needed bloats? (press y)"

lastwords="Now that installation is finished, you are free to either enter chroot or reboot and use your pc as you wish (press c for chroot, press r for reboot)"


fornvme() {
    ## get disk name
    echo "dont mind this"
    device="/dev/nvme0n1"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    cfdisk $device

    ## format disk
    echo "formatting disk"
    mkfs.vfat -F32 ${device}p1
    mkswap ${device}p2
    mkfs.ext4 ${device}p3

    ## mount disk
    echo "mounting disk"
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

    #setup users
    setupusers

    ## fstab
    bastardfstabnvme

    ##install grub
    installgrub

    ## last touch
    lasttouch

    ##ask bloats
    answerbloats

    ## ask last words
    answerlastwords

}

forsda() {
    ## get disk name    #working
    echo "dont mind these outputs"
    device="/dev/sda"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    rm -rf /mnt/*
    cfdisk $device
    echo "finished"

    ## format disk      #working
    echo "formatting disk"
    mkfs.vfat -F32 ${device}1
    mkswap ${device}2
    mkfs.ext4 ${device}3
    echo "finished"

    ## mount disk       #working
    echo "mounting disk"
    mount ${device}3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${device}1 /mnt/boot/efi
    swapon ${device}2
    echo "finished"

    ## download tarball     #working
    downloadtarball

    ## mount to chroot     #working
    mountfilesandchroot

    ##setup repo            #working
    setuprepo

    ## install system       #working
    installsystem

    ## prepare system       #working
    prepare

    #setup users        #working
    setupusers

    ## fstab           #working
    bastardfstabsda

    ##install grub
    installgrub

    ## last touch
    lasttouch

    ##ask bloats
    answerbloats

    ## ask last words
    answerlastwords
}



downloadtarball() {
    echo "downloading tarball"
    wget -O /tmp/void.tar.xz https://repo-fastly.voidlinux.org/live/current/void-x86_64-ROOTFS-20240314.tar.xz
    tar -xvf /tmp/void.tar.xz -C /mnt
    echo "finished"
}

mountfilesandchroot() {
    echo "mounting"
    mount -t proc none /mnt/proc
    mount -t sysfs none /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --rbind /run /mnt/run
    cp /etc/resolv.conf /mnt/etc/resolv.conf
    echo "finished"
}

setuprepo() {
    echo "fastest repos installing"
    rm /mnt/usr/share/xbps.d/00-repository-main.conf
    touch /mnt/usr/share/xbps.d/00-repository-main.conf
    # Append new repository URLs using echo
    echo 'repository=https://repo-default.voidlinux.org/current' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-default.voidlinux.org/current/nonfree' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-default.voidlinux.org/current/multilib' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-default.voidlinux.org/current/multilib/nonfree' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo "finished"
}

installsystem() {
    echo "installing system"
    $installcommand "xbps-install -Suy xbps"
    $installcommand "xbps-install -uy"
    touch /mnt/usr/share/xbps.d/bloats.conf
    echo "ignorepkg=linux-firmware-broadcom" >> /mnt/usr/share/xbps.d/bloats.conf
    $installcommand "xbps-install -y $needed" 
    $installcommand "xbps-remove -y $bloat"
    echo "finished"
}

prepare() {
    echo "preparing system, better get ready!!"
    $installcommand "mount -t efivarfs none /sys/firmware/efi/efivars"
    vim /mnt/etc/hostname
    vim /mnt/etc/rc.conf
    vim /mnt/etc/default/libc-locales
    $installcommand "xbps-reconfigure -f glibc-locales"
    echo "finished"
}


setupusers() {
    echo "enter root password 2 times"
    $installcommand "passwd root"
    echo "enter username"
    read username
    $installcommand "useradd -m -G wheel,video,audio $username"
    echo "enter password for $username"
    $installcommand "passwd $username"
    echo "finished"
}


installgrub() {
    echo "uninstall grub and install refind after opening system"
    $installcommand "xbps-install -y grub-x86_64-efi"
    $installcommand "grub-install"
    echo "finished"
}

lasttouch() {
    $installcommand "xbps-reconfigure -fa"
}



bastardfstabnvme() {
    $installcommand "rm /etc/fstab"
    root_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p3| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
efi_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p1| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
swap_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p2| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")

    $installcommand "touch $FSTAB_FILE"
    $installcommand "echo \"$root_UUID / ext4 defaults 0 1\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$efi_UUID /boot/efi vfat defaults 0 2\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$swap_UUID swap swap defaults 0 0\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"tmpfs /tmp tmpfs defaults 0 0\" | tee -a $FSTAB_FILE"
}


bastardfstabsda() {
    $installcommand "rm /etc/fstab"
    root_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda3 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
efi_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda1 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
swap_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda2 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")

    $installcommand "touch $FSTAB_FILE"
    $installcommand "echo \"$root_UUID / ext4 defaults 0 1\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$efi_UUID /boot/efi vfat defaults 0 2\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$swap_UUID swap swap defaults 0 0\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"tmpfs /tmp tmpfs defaults 0 0\" | tee -a $FSTAB_FILE"
}

answerbloats() {
    echo $askbloats
    read answeredbloats
    if [ "$answeredbloats" == "y" ]; then
        touch /mnt/etc/doas.conf
        echo 'permit persist :wheel' >> /mnt/etc/doas.conf
        $installcommand "xbps-install -Sy $neededbloat"
        $installcommand "ln -s /etc/sv/connmand /etc/runit/runsvdir/default/"
        $installcommand "ln -s /etc/sv/dbus /etc/runit/runsvdir/default/"
        $installcommand "rm -rf /etc/runit/runsvdir/default/agetty-tty4 /etc/runit/runsvdir/default/agetty-tty5 /etc/runit/runsvdir/default/agetty-tty6"
        $installcommand "ln -s /etc/sv/chronyd /etc/runit/runsvdir/default"
        $installcommand "ln -s /etc/sv/alsa/ /etc/runit/runsvdir/default/"
    fi
}

answerlastwords() {
    echo $lastwords
    read answeredlastwords
    if [ "$answeredlastwords" == "c" ]; then
        chroot /mnt /bin/sh
    elif [ "$answeredlastwords" == "r" ]; then
        umount -R /mnt
        reboot
    fi
}




if [ "$output" == "sda" ]; then
   forsda
elif [ "$output" == "nvme" ]; then
    fornvme
else
    echo "nuh uh"
fi


