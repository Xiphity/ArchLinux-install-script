step1(){
    read -p "hostname: " hostname
    read -p "username: " username
    read -p "password: " password
    echo 'Configure mirrorlist ...'
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    
    pacman -Sy reflector
    reflector --verbose --latest 100 --sort rate --country 'Taiwan' --save /etc/pacman.d/mirrorlist

    echo 'Install ArchLinux ...'
    pacstrap /mnt base base-devel linux-lts linux-headers linux-firmware
    pacstrap /mnt amd-ucode  intel-ucode git gnome gnome-extra nvidia-utils nvidia nvidia-lts nvidia-dkms
    echo 'Generate fstab ...'
    genfstab -p -U /mnt >> /mnt/etc/fstab

    #chroot
    cp $0 /mnt/install.sh
    arch-chroot /mnt bash /install.sh --config $hostname $username $password
    rm /mnt/install.sh
    echo 'System installed. Please reboot.'
    exit
}

step2(){
    echo 'Configure pacman ...'
    sed -i '/^#\[multilib\]$/{N;s/#//g;P;D;}' /etc/pacman.conf
    pacman -Sy reflector
    reflector --verbose --latest 100 --sort rate --country 'Taiwan' --save /etc/pacman.d/mirrorlist

    echo 'Install packages ...'

    pacman -Sy  gedit vim net-tools wireless_tools dhclient wpa_supplicant grub os-prober efibootmgr
    pacman -S fcitx-im fcitx-chewing fcitx-configtool
    pacman -S noto-fonts noto-fonts-cjk ttf-roboto ttf-roboto-mono ntfs-3g
    echo 'Change system limit ...'
    echo '*               -       nofile          10000' >> /etc/security/limits.conf

    echo 'Configure sudo ...'
    sed -i 's/^# \(%wheel ALL=(ALL) ALL\)$/\1/' /etc/sudoers

    echo 'Configure network ...'
    echo '$hostname' > /etc/hostname
    echo '127.0.0.1  $hostname.localdomain  $hostname' >> /etc/hosts
    systemctl enable NetworkManager	
    echo 'nameserver 1.1.1.1' > /etc/resolv.conf #cloudfare dns
    echo 'nameserver 1.0.0.1' >> /etc/resolv.conf
    echo 'Configure time ...'
    # 時區
    ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
    # 網路時間同步
    systemctl enable ntpd.service


    echo 'Configure Locale ...'
    mv /etc/locale.gen /etc/locale.gen.bak
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
    echo 'zh_TW.UTF-8 UTF-8' >> /etc/locale.gen
   
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    echo 'Configure IME ...'
    echo 'LANG=zh_TW.UTF-8' >> /etc/skel/.xprofile
    echo 'export GTK_IM_MODULE=fcitx' >> /etc/skel/.xprofile
    echo 'export QT_IM_MODULE=fcitx' >> /etc/skel/.xprofile
    echo 'export XMODIFIERS=@im=fcitx' >> /etc/skel/.xprofile

    echo 'Configure graphical UI...'
    systemctl enable gdm
    systemctl enable NetworkManager
    echo 'Creating boot image ...'
    mkinitcpio -p linux

    echo 'Create user account'
    useradd -m -u 1001 $username 
    echo "$username:$password" |chpasswd
    usermod $username -G wheel

    echo 'Configure Grub:'
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
    grub-mkconfig -o /boot/grub/grub.cfg
	systemctl enable dhcpcd.service
	exit
}

if [ $# != 0 ] && [ "$1" == "--config" ]; then
    hostname=$2
    username=$3
    password=$4
    step2;
else
    step1;
fi