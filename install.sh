#!/usr/bin/env bash


set -euo pipefail


clear


VMCHECK=$(systemd-detect-virt)
SOURCE=$(dirname "${BASH_SOURCE[0]}")
CHROOT="arch-chroot /mnt /bin/bash -c"


main () {
	greeter
	makepart
	makefs
	mountpart
	selectpkgs
	cpconfigs
	sysconfig
	sethome
	themes
	goodbye
}


# greeter prompt to run installer
greeter () {

	echo -e "You're about to install Arch Linux (hardened)\n"
	read -r -p "Continue? [Y/n] "

	case "${REPLY,,}" in
	 y)
	 	echo -e "\nContinuing to installation ...\n"
		sleep 0.5
		;;
	 n)
		echo -e "\nOK, maybe next time!"
		exit
		;;
	 *)
		clear
		greeter
		;;
	esac
}


# choose device, partition with fdisk
makepart () {

	echo -e "Where would you like to install?\n"
	lsblk

	echo -e "\nEnter device to partition (eg; /dev/sdx)\n"
	read -r -p "> " DEVICE; clear

	fdisk "$DEVICE"
	if [[ $? != 0 ]]; then
		clear
		echo -e "Please try again!\n"
		sleep o.6
		makepart
	fi
}


# filesystem for new partions
makefs () {

	echo -e "Choose a filesystem for partitions: (ext4, xfs, btrfs)\n"
	read -r -p "> " FSTYPE

	PARTION=$(lsblk "$DEVICE" | grep -c part)
	for PART in $(seq 1 "$PARTION")
	do
		echo
		mkfs."$FSTYPE" "${DEVICE}${PART}"
	done
}


# mount partions for installation
mountpart () {

	echo -e "\nmounting ${DEVICE}1 /mnt ..."
	mount "${DEVICE}1" /mnt

	case $PARTION in
	 2)
		echo "mounting ${DEVICE}2 /mnt/home ..."
		mkdir -p /mnt/home
		mount "${DEVICE}2" /mnt/home
		;;
	 3)
		echo "mounting ${DEVICE}2 /mnt/var ..."
		mkdir -p /mnt/var
		mount "${DEVICE}2" /mnt/var

		echo "mounting ${DEVICE}3 /mnt/home ..."
		mkdir -p /mnt/home
		mount "${DEVICE}3" /mnt/home
		;;
	 *)
		;;
	esac
}


# install base and package options
selectpkgs () {

	echo -e "\nSelect additional packages: (1, 2, 5..)\n"

	# list package groups
	PACKAGES=("Xorg" "Xfce" "Apps" "Utils" "All" "None")
	for PKG in "${!PACKAGES[@]}"; do
		printf "%2d) %s\n" $((PKG+1)) "${PACKAGES[${PKG}]}"
	done

	echo
	read -r -p "> "

	# sanitize options
	OPTIONS=$(echo "$REPLY" | awk '$1=$1' FS= OFS=" ")
	if [[ -f ${SOURCE}/packages ]]; then
		source packages 0 $OPTIONS
	else
		echo "Source file not found."
	fi
}


# copy config files to /mnt
cpconfigs () {

	# copy to /etc
	echo -e "\nCopying config files to /etc ..."
	if [[ -d ${SOURCE}/etc ]]; then
		cp -r etc/. /mnt/etc
	else
		echo -e "\nSource directory not found."
	fi

	# copy to /usr
	echo -e "\nCopying config files to /usr ..."
	if [[ -d ${SOURCE}/usr ]]; then
		cp -r usr/. /mnt/usr
	else
		echo -e "\nSource directory not found."
	fi
}


# set root password
rootpass () {

	read -rp "Choose 'root' password: " -s ROOTPASS1; echo
	read -rp "Retype 'root' password: " -s ROOTPASS2; echo

	if [[ $ROOTPASS1 = "$ROOTPASS2" ]]; then
		$CHROOT "(echo $ROOTPASS1 ; echo $ROOTPASS2) | passwd root"
	else
		echo "Passwords do not match, please try again"
		rootpass
	fi
}


# set user password
userpass () {

	read -rp "Choose password for ${NAME}: " -s USERPASS1; echo
	read -rp "Retype password for ${NAME}: " -s USERPASS2; echo

	if [[ $USERPASS1 = "$USERPASS2" ]]; then
		$CHROOT "(echo $USERPASS1 ; echo $USERPASS2) | passwd $NAME"
	else
		echo "Passwords do not match, please try again"
		userpass
	fi
}


# configure filesystem table
makefstab () {

	FSTAB=/mnt/etc/fstab

	# generate fstab
	echo -e "\nGenerating /mnt/etc/fstab ..."
	genfstab -U /mnt >> "$FSTAB"

	if [[ $? = 0 ]]; then

		sed -i \
		-e '/boot/ s=relatime=noatime=' \
		-e '/\/[[:space:]]/ s=relatime=noatime=' \
		-e '/home/ s=relatime=noatime,nodev,nosuid=' \
		-e '/var/ s=relatime=noatime,nodev,nosuid=' \
		-e 's/\S\+/0/5' -e 's/\S\+/0/6' \
		"$FSTAB"

		{
		echo "/tmp	/var/tmp	none	rw,nodev,nosuid,noexec,bind  0 0"
		echo "tmpfs	/tmp		tmpfs	rw,nodev,nosuid,noexec	0 0"
		echo "tmpfs	/dev/shm	tmpfs	rw,nodev,nosuid,noexec	0 0"
		echo "proc	/proc		proc	rw,nodev,noexec,nosuid,hidepid=2  0 0"
		} >> "$FSTAB"
	fi
}


# main system setup
sysconfig () {

	clear
	echo -e "\nAll packages installed. Ready to configure.\n \
	\nAny key to continue ...\n"
	read -n1 -rs

	# set hostname
	echo -e "\nChoose system hostname: "
	read -r HOST
	echo "$HOST" > /mnt/etc/hostname

	# change root password
	echo; rootpass

	# create 'non-root' user
	echo -e "\nChoose a user name:"
	read -r NAME
	$CHROOT "useradd -mG wheel -s /bin/bash $NAME"

	# set user password
	echo; userpass

	# install grub and generate config file
	echo -e "\nGenerating grub configuration ..."
	$CHROOT "grub-install ""$DEVICE"""
	$CHROOT "grub-mkconfig -o /boot/grub/grub.cfg"

	# create fstab
	makefstab

	# set system localization
	echo -e "\nSetting system localization ..."
	sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
	$CHROOT "locale-gen"
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

	# set timezone and hardware clock
	echo -e "\nSetting timezone and clock ..."
	$CHROOT "ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime"
	$CHROOT "hwclock --systohc --utc"

	# configure /etc/hosts file
	echo -e "\nConfiguring /etc/hosts file ..."
	echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$HOST" > /mnt/etc/hosts

	# configure arch-sudo file
	if [[ -f /mnt/etc/sudoers.d/arch-sudo ]]; then
		echo -e "\nConfiguring arch-sudo file..."
		sed -i "s|<user>|${NAME}|g" /mnt/etc/sudoers.d/arch-sudo
	fi

	# configure lxdm
	if $CHROOT "pacman -Qi lxdm" &> /dev/null; then
		echo -e "\nConfiguring lxdm ..."
		sed -i "s|<user>|${NAME}|g" /mnt/etc/lxdm/lxdm.conf
	fi

	# configure reflector
	if $CHROOT "pacman -Qi reflector" &> /dev/null; then
		echo -e "\nConfiguring reflector ..."
		$CHROOT "reflector @/etc/xdg/reflector/reflector.conf --save /etc/pacman.d/mirrorlist"
	fi

	# configure firewalld
	if $CHROOT "pacman -Qi firewalld" &> /dev/null; then
		echo -e "\nConfiguring firewalld ..."
		$CHROOT "firewall-offline-cmd --set-default-zone=drop"
		$CHROOT "firewall-offline-cmd --add-icmp-block-inversion"
	fi

	# config wpa_supplicant if needed
	if [[ $VMCHECK = none ]]; then
		if $CHROOT "pacman -Qi networkmanager" &> /dev/null; then
			:
		else
			echo -e "\nConfiguring wpa_supplicant ..."
			echo -e "\nEnter network ssid:"; read -r SSID
			echo -e "\nEnter passphrase:"; read -r PSK
			$CHROOT "wpa_passphrase ""${SSID}"" ""${PSK}"" > /etc/wpa_supplicant/wpa_supplicant.conf"
		fi
	fi
}


# setup /home directory
sethome () {

	mkdir -p /mnt/home/"${NAME}"/Documents
	mkdir -p /mnt/home/"${NAME}"/Downloads
	mkdir -p /mnt/home/"${NAME}"/Projects
	mkdir -p /mnt/home/"${NAME}"/AUR

	# copy dotfiles
	echo -e "\nCopying files to /home/${NAME} ..."

	if [[ -d ${SOURCE}/home ]]; then
		if $CHROOT "pacman -Qi xfdesktop" &> /dev/null; then
			cp -r home/. /mnt/home/"${NAME}"
		else
			( cd "${SOURCE}"/home;
			for f in .aliases .profile .bashrc .inputrc .bin; do
				cp -r "$f" /mnt/home/"${NAME}"
			done )
		fi
	fi

	$CHROOT "chown -R ${NAME}:${NAME} /home/${NAME}"
	$CHROOT "chmod -R 750 /home/${NAME}"
}


# configure desktop theme
themes () {

	if $CHROOT "pacman -Qi xfdesktop" &> /dev/null; then

		echo -e "\nInstalling desktop themes ..."
		for f in "${SOURCE}"/home/.themes/*.tar.xz; do
			tar xf "$f" -C /mnt/usr/share/themes/
			echo "done"
		done

		echo -e "\nInstalling icon themes ..."
		for f in "${SOURCE}"/home/.icons/*.tar.xz; do
			tar xf "$f" -C /mnt/usr/share/icons/
			echo "done"
		done
	fi
}


# installation complete
goodbye () {

	echo -e "\nInstallation complete. Any key to reboot.."
	read -n1 -rs

	umount -R /mnt

	rm -rf -- "$(pwd)"

	reboot
}


# call main, parse script
main "$@"

