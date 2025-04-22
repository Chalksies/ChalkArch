#!/usr/bin/env -S bash -e

clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
BPURPLE='\e[95m'
BCYAN='\e[36m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} > $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BCYAN}[ ${BGREEN}•${BCYAN} > $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} > $1${RESET}"
}

# Virtualization check (function).
virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )   info_print "KVM has been detected, setting up guest tools."
                pacstrap /mnt qemu-guest-agent &>/dev/null
                systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                ;;
        vmware  )   info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."
                    pacstrap /mnt open-vm-tools >/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    info_print "VirtualBox has been detected, setting up guest tools."
                    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) info_print "Hyper-V has been detected, setting up guest tools."
                    pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "List of kernels:"
    info_print "-----------------------------------------------------------------------------------------------------------------------"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
    info_print "2) Hardened: A security-focused Linux kernel"
    info_print "3) Longterm: Long-term support (LTS) Linux kernel"
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage"
    info_print "-----------------------------------------------------------------------------------------------------------------------"
    input_print "Please select the number of the corresponding kernel (e.g. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "You did not enter a valid selection, please try again."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Network utilities:"
    info_print "-----------------------------------------------------------------------------------------------------------------------"
    info_print "1) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "2) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    info_print "-----------------------------------------------------------------------------------------------------------------------"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice
    if ! ((1 <= network_choice <= 5)); then
        error_print "Invalid selection, please try again."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installing and enabling IWD."
            pacstrap /mnt iwd >/dev/null
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installing and enabling NetworkManager."
            pacstrap /mnt networkmanager >/dev/null
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installing and enabling wpa_supplicant and dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installing dhcpcd."
            pacstrap /mnt dhcpcd >/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
    esac
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (it will not appear on screen): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "Password cannot be empty, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (it will not appear on screen): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector () {
    input_print "Please enter a password for the root user (it will not appear on screen): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "Root password cannot be empty. Please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (it will not appear on screen): " 
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected. The AMD microcode will be installed."
        microcode="amd-ucode"
    elif [[ "$CPU" == *"GenuineIntel"* ]]; then
        info_print "An Intel CPU has been detected. The Intel microcode will be installed."
        microcode="intel-ucode"
    else
        error_print "Your CPU is neither Intel nor AMD. If you are using an ARM CPU, please terminate this installation and try \"Arch Linux ARM\", a fork of Arch Linux designed for ARM CPUs."
    fi
}

hostname_selector () {
    input_print "Please enter the hostname for the machine: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search through available locales): " locale
    read -r locale
    case "$locale" in
        '') locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0;;
        '/') sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
                clear
                return 1;;
        *)  if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "This locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
    esac
}

keyboard_selector () {
    input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to search through available keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
        '') kblayout="us"
            info_print "The standard US keyboard layout will be used."
            return 0;;
        '/') localectl list-keymaps
             clear
             return 1;;
        *) if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
               error_print "This keymap doesn't exist."
               return 1
           fi
        info_print "Changing console layout to $kblayout."
        loadkeys "$kblayout"
        return 0
    esac
}

environment_selector () {
    info_print "Choose a desktop environment/window manager to install:"
    PS3="Enter the number of your choice: "

    options=("GNOME" "KDE Plasma" "XFCE" "Cinnamon" "MATE" "i3" "Sway" "[Other]" "[None (headless)]")
    select de in "${options[@]}"; do
        case $REPLY in
            1) DESKTOP_ENV="gdm gnome gnome-tweaks"; break ;;
            2) DESKTOP_ENV="sddm plasma-meta konsole kate dolphin ark plasma-workspace"; break ;;
            3) DESKTOP_ENV="xorg-server xorg-apps lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4 xfce4-goodies pavucontrol gvfs xarchiver"; break ;;
            4) DESKTOP_ENV="xorg-server xorg-apps lightdm slick-greeter cinnamon system-config-printer gnome-keyring gnome-terminal blueman bluez-utils engrampa gnome-screenshot gvfs-smb xed xdg-user-dirs-gtk"; break ;;
            5) DESKTOP_ENV="xorg-server xorg-apps lightdm lightdm-gtk-greeter mate mate-extra"; break ;;
            6) DESKTOP_ENV="xorg-server xorg-apps i3-wm i3lock i3status i3blocks xss-lock xterm lightdm-gtk-greeter lightdm dmenu"; break ;;
            7) DESKTOP_ENV="sway swaybg swaylock swayidle waybar dmenu brightnessctl grim slurp pavucontrol foot xorg-xwayland polkit"; break ;;
            8) DESKTOP_ENV="other"; break;;
            9) DESKTOP_ENV=""; break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    if [[ "$DESKTOP_ENV" == "other" ]]; then
        while true; do
            input_print "Enter the name of the DE/WM package you want to use (e.g. budgie, awesome, bspwm, etc.):"
            read -r other_desktop

            if pacman -Si "$other_desktop" &>/dev/null; then
                DESKTOP_ENV="$other_desktop"
                info_print "Package '$DESKTOP_ENV' found in the repositories and will be installed."

                break
            else
                error_print "Package '$other_desktop' not found. Please try again."
            fi
        done
    fi
    done
}

soundserver_selector () {
    info_print "Choose an audio server to install:"
    PS3="Enter the number of your choice: "

    options=("PipeWire" "PulseAudio" "[None]")
    select de in "${options[@]}"; do
        case $REPLY in
            1) SOUND_SERVER="pipewire pipewire-alsa wireplumber pipewire-pulse pipewire-jack gst-plugin-pipewire libpulse"; break ;;
            2) SOUND_SERVER="pulseaudio pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack pulseaudio-lirc pulseaudio-zeroconf"; break ;;
            3) SOUND_SERVER=""; break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}


chroot_exec() {
    arch-chroot /mnt /bin/bash -c "$1"
}


# Script start
echo -ne "${BOLD}${BPURPLE}
========================================================================
 ██████╗██╗  ██╗ █████╗ ██╗     ██╗  ██╗ █████╗ ██████╗  ██████╗██╗  ██╗
██╔════╝██║  ██║██╔══██╗██║     ██║ ██╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║
██║     ███████║███████║██║     █████╔╝ ███████║██████╔╝██║     ███████║
██║     ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══██║██╔══██╗██║     ██╔══██║
╚██████╗██║  ██║██║  ██║███████╗██║  ██╗██║  ██║██║  ██║╚██████╗██║  ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
========================================================================
${RESET}"
info_print "Welcome to ChalkArch. This script will help you install Arch Linux on your machine."

# Setting up keyboard layout.
until keyboard_selector; do : ; done

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK="$ENTRY"
    info_print "ChalkArch will install Arch Linux on the following disk: $DISK"
    break
done

# Setting up the kernel.
until kernel_selector; do : ; done

# Choose DE/WM
until environment_selector; do : ; done

# User choses the network.
until network_selector; do : ; done

# User choses the locale.
until locale_selector; do : ; done

# User choses the hostname.
until hostname_selector; do : ; done

# User sets up the user/root passwords.
until userpass_selector; do : ; done
until rootpass_selector; do : ; done

clear

input_print "The installer will now remove the current partition table on $DISK. This operation will remove all data on $DISK and cannot be undone. Proceed? [y/N]:"
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Aborting install."
    exit
fi
info_print "Wiping $DISK."
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null

input_print "Seperate the /home and root partitions? [Y/n]:"
read -r home_partition_setting
if ! [[ "${home_partition_setting}" =~ ^(no|n|No|N)$ ]]; then
    SEPERATE_PARTITIONS=true
    while true; do
        input_print "Size of the root partition? 25 to 50GiB is recommended. The rest of the disk will be used for the /home partition. Syntax: Parted syntax, only MiB and GiB. (40GiB, 40960MiB etc.)"
        read -r ROOTSIZE

        if [[ "$ROOTSIZE" =~ ^([0-9]+)(MiB|GiB)$ ]]; then
            SIZE_NUM=$(echo "$ROOTSIZE" | sed -E 's/^([0-9]+)(GiB|MiB)$/\1/')
            SIZE_UNIT=$(echo "$ROOTSIZE" | sed -E 's/^([0-9]+)(GiB|MiB)$/\2/')

            #echo "sizeNum: $SIZE_NUM"
            #echo "sizeUnit: $SIZE_UNIT"
            #sleep 3s

            # Convert to GiB for checking
            if [[ "$SIZE_UNIT" == "MiB" ]]; then
                SIZE_GIB=$(awk "BEGIN { printf \"%.2f\", $SIZE_NUM / 1024 }")
            else
                SIZE_GIB="$SIZE_NUM"
            fi

            #echo "sizeGiB: $SIZE_GIB"
            #sleep 3s

            SIZE_GIB_CLEAN=$(echo "$SIZE_GIB" | tr -d '[:space:]')

            #echo "sizeGiBClean: $SIZE_GIB_CLEAN"
            #sleep 3s

            if [[ "$SIZE_GIB_CLEAN" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                SIZE_GIB_INT=$(printf "%.0f" "$SIZE_GIB_CLEAN")
            else
                error_print "Unexpected error parsing size. Please try again."
                continue
            fi

            #echo "sizeGinbInt: $SIZE_GIB_INT"
            #sleep 3s

            # Check if it's within range
            if (( SIZE_GIB_INT < 25 || SIZE_GIB_INT > 50 )); then
                info_print "You entered ${ROOTSIZE} (~${SIZE_GIB}GiB), which is outside the recommended 25-50GiB range."
                input_print "Are you sure you want to continue with this size? Making a too small root partition might cause the installation to fail.[y/N]"
                read -r confirm_size
                if [[ "$confirm_size" =~ ^(y|Y|yes|Yes)$ ]]; then
                    # Accept out-of-range value

                    # Handle partition size for later.
                    if [[ "$SIZE_UNIT" == "GiB" ]]; then
                        ROOTSIZE_MIB=$(awk "BEGIN { print $SIZE_NUM * 1024 }")
                    else
                        ROOTSIZE_MIB="$SIZE_NUM"
                    fi

                    ROOT_END_MIB=$(awk "BEGIN { print $ROOTSIZE_MIB + 1025 }")
                    break
                else
                    info_print "Let's try again."
                    continue
                fi
            else
                # Valid and in range

                # Handle partition size for later.
                if [[ "$SIZE_UNIT" == "GiB" ]]; then

                    echo "if condition succeded."
                    sleep 1
                    ROOTSIZE_MIB=$(awk -v s="$SIZE_NUM" 'BEGIN { print s * 1024 }')
                else
                    echo "if condition failed."
                    sleep 1
                    ROOTSIZE_MIB="$SIZE_NUM"
                fi

                #echo "rootSizeMiB: $ROOTSIZE_MIB"
                #sleep 3

                ROOT_END_MIB=$(awk "BEGIN { print $ROOTSIZE_MIB + 1025 }")
                break
            fi
        else
            error_print "Invalid syntax. Please enter a size like 20GiB or 20480MiB."
        fi
    done
else
    SEPERATE_PARTITIONS=false
    info_print "Home partition will not be separated."
fi

# Creating a new partition scheme.
info_print "Creating new partitions on $DISK."

if [ "$SEPERATE_PARTITIONS" = true ]; then

    parted -s "$DISK" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 1025MiB \
        set 1 esp on \
        name 1 ESP \
        mkpart ROOT ext4 1025MiB "${ROOT_END_MIB}MiB"\
        name 2 ROOT \
        mkpart HOME ext4 "${ROOT_END_MIB}MiB" 100% \
        name 3 HOME

    udevadm settle
    HOME=$(lsblk -o PATH,PARTLABEL | awk '$2 == "HOME" { print $1 }')
else

    parted -s "$DISK" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 1025MiB \
        set 1 esp on \
        name 1 ESP \
        mkpart ROOT ext4 1025MiB 100% \
        name 2 ROOT 

    udevadm settle
fi

ESP=$(lsblk -o PATH,PARTLABEL | awk '$2 == "ESP" { print $1 }')
ROOT=$(lsblk -o PATH,PARTLABEL | awk '$2 == "ROOT" { print $1 }')


# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the partitions
info_print "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 "$ESP" &>/dev/null
info_print "Formatting the Root Partition as ext4"
mkfs.ext4 "$ROOT" &>/dev/null
if [ "$SEPERATE_PARTITIONS" = true ]; then
    info_print "Formatting the Home Partition as ext4"
    mkfs.ext4 "$HOME" &>/dev/null
fi

# Mounting the newly created subvolumes.
umount /mnt &>/dev/null
info_print "Root is $ROOT"
info_print "Mounting the newly created partitions."
mount "$ROOT" /mnt &>/dev/null
mount --mkdir "$ESP" /mnt/boot &>/dev/null
if [ "$SEPERATE_PARTITIONS" = true ]; then
    mount --mkdir "$HOME" /mnt/home &>/dev/null
fi

# Checking the microcode to install.
microcode_detector

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (this might take a while)."
pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers pipewire grub rsync efibootmgr zram-generator sudo nano htop wget &>/dev/null


if [[ -n "$DESKTOP_ENV"]]; then
    info_print "Installing DE/WM of choice and additional packages (this might take a while)"
    chroot_exec "pacman -S --noconfirm $DESKTOP_ENV &>/dev/null"


    if [[ "$DESKTOP_ENV" == *"gdm"* ]]; then
        info_print "Enabling display manager."
        chroot_exec "systemctl enable gdm"

    elif [[ "$DESKTOP_ENV" == *"sddm"* ]]; then
        info_print "Enabling display manager."
        chroot_exec "systemctl enable sddm"

    elif [[ "$DESKTOP_ENV" == *"lightdm"* ]]; then
        info_print "Enabling display manager."
        chroot_exec "systemctl enable lightdm"

    fi
fi

if [ -n "$SOUND_SERVER"]; then
    info_print "Installing audio server."
    chroot_exec "pacman -S --noconfirm $SOUND_SERVER &>/dev/null"
fi


# Setting up the hostname.
echo "$hostname" > /mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new filesystem table."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure selected locale and console keymap
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

# Setting hosts file.
info_print "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Virtualization check.
virt_check

# Setting up the network.
network_installer

# Configuring /etc/mkinitcpio.conf.
info_print "Configuring /etc/mkinitcpio.conf."
cat > /mnt/etc/mkinitcpio.conf <<EOF
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
EOF

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, GRUB)."
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Boot backup hook.
info_print "Configuring /boot backup when pacman transactions are made."
mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

# ZRAM configuration.
info_print "Configuring ZRAM."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF

# Pacman eye-candy features.
info_print "Enabling colours, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf

# Finishing up.
info_print "System installation complete."
info_print "ChalkArch will now exit. You may reboot, or chroot into /mnt to configure the newly installed system."

exit