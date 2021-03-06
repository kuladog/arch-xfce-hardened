#!/usr/bin/env bash


set -euo pipefail


clear


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
	decorate
	goodbye
}


status () {
	if [[ $? -eq 0 ]]; then
		echo "success"
	else
		echo "failed"
	fi
}


# greeter prompt to run installer
greeter () {

	cat <<- EOF


	        AA
	       AA  A                        hh              xx    xx
	      AA   AA                       hh               xx  xx
	     AA     AA     rr rrr    cccc   hhhhh              xx
	    AA  AAA  AA    rrrr    cc       hh   hh   ====    xxx
	   AA         AA   rr      cc       hh   hh          xx  xx
	  AA           AA  rr        cccc   hh   hh         xx    xx


	           ARCH LINUX - XFCE - HARDENED - by Kuladog



	EOF

	echo -e "\nYou're about to install Arch Linux (Hardened)\n"
	read -r -p"Continue? [Y/n] "; clear

	case "${REPLY,,}" in
	 y)
	 	echo -e "\nContinuing to installation ...\n"
		sleep 1.5
		clear
		;;
	 n)
		echo -e "\nOK, maybe next time!\n"
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

	echo -e "\nCurrent local drives available:\n"
	lsblk | grep "sd\|hd\|vd"

	echo
	echo -e "\nEnter device to partition (sdc, vda, etc.)\n"
	read -r -p "> " DISK; DISK=${DISK,,}
	clear

	DISKCHECK=($(lsblk | grep -o "^sd\w*\|^nvme\w*|hd\w*\|^vd\w*"))
	if [[ ! ${DISKCHECK[@]} =~ ${DISK} ]]; then
		clear
		echo -e "Please try again!\n"
		sleep 0.8
		makepart
	fi

	fdisk /dev/"${DISK}"
}


# filesystem for new partions
makefs () {

	DEVICE=/dev/"${DISK}"

	clear
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
		source packages 0 "$OPTIONS"
	else
		echo "ERROR: Source 'packages' not found."
	fi
}


# copy config files to /mnt
cpconfigs () {

	# copy to /etc
	if [[ -d ${SOURCE}/etc ]]; then
		echo -e "\nCopying config files to /etc ..."
		cp -r etc/. /mnt/etc
		status
	fi

	# copy to /etc/skel
	if [[ -d ${SOURCE}/skel ]]; then
		echo -e "\nCopying config files to /etc/skel ..."
		cp -r skel/. /mnt/etc/skel
		status
	fi

	# copy to /usr
	if [[ -d ${SOURCE}/usr ]]; then
		echo -e "\nCopying config files to /usr ..."
		cp -r usr/. /mnt/usr
		status
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

	if genfstab -U /mnt >> "$FSTAB"; then

		sed -i \
		-e '/boot/ s=relatime=noatime=' \
		-e '/\/[[:space:]]/ s=relatime=noatime=' \
		-e '/home/ s=relatime=noatime,nodev,nosuid=' \
		-e '/var/ s=relatime=noatime,nodev,nosuid=' \
		-e 's/\S\+/0/5' \
		-e 's/\S\+/0/6' \
		"$FSTAB"

		{
		echo "/tmp	/var/tmp	none	nodev,nosuid,noexec,bind	0 0"
		echo "tmpfs	/tmp		tmpfs	nodev,nosuid,noexec	0 0"
		echo "tmpfs	/dev/shm	tmpfs	nodev,nosuid,noexec	0 0"
		echo "proc	/proc		proc 	nodev,nosuid,noexec	0 0"
		} >> "$FSTAB"
	fi

	status
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
	echo -e "\nGenerating fstab ..."
	makefstab

	# set system localization
	sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
	$CHROOT "locale-gen" &> /dev/null
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
	status

	# set timezone and hardware clock
	echo -e "\nSetting timezone and clock ..."
	$CHROOT "ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime"
	$CHROOT "hwclock --systohc --utc"
	status

	# configure /etc/hosts file
	echo -e "\nConfiguring /etc/hosts file ..."
	echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$HOST" > /mnt/etc/hosts
	status

	# configure arch-sudo file
	if [[ -f /mnt/etc/sudoers.d/arch-sudo ]]; then
		echo -e "\nConfiguring arch-sudo file..."
		sed -i "s|<user>|${NAME}|g" /mnt/etc/sudoers.d/arch-sudo
		status
	fi

	# configure lxdm
	if $CHROOT "pacman -Qi lxdm" &> /dev/null; then
		echo -e "\nConfiguring display manager ..."
		sed -i "s|<user>|${NAME}|g" /mnt/etc/lxdm/lxdm.conf
		status
	fi

	# configure reflector
	if $CHROOT "pacman -Qi reflector" &> /dev/null; then
		echo -e "\nConfiguring reflector ..."
		$CHROOT "reflector @/etc/xdg/reflector/reflector.conf --save /etc/pacman.d/mirrorlist"
		status
	fi

	# configure firewalld
	if $CHROOT "pacman -Qi firewalld" &> /dev/null; then
		echo -e "\nConfiguring firewalld ..."
		$CHROOT "firewall-offline-cmd --set-default-zone=drop" &> /dev/null
		$CHROOT "firewall-offline-cmd --add-icmp-block-inversion" &> /dev/null
    status
	fi

	# config wpa_supplicant if needed
	if [[ $(systemd-detect-virt) = none ]]; then
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

	mkdir -p /mnt/home/"${NAME}"/{Documents,Downloads,Projects}

	echo -e "\nSetting permissions for /home/* ..."

	$CHROOT "chown -R ${NAME}:${NAME} /home/${NAME}"
	$CHROOT "chmod -R 750 /home/${NAME}"
	status
}


# configure desktop theme
decorate () {

	if $CHROOT "pacman -Qi xfdesktop" &> /dev/null; then

		echo -e "\nSetting desktop and icon theme ..."

		pacstrap /mnt wget papirus-icon-theme
		$CHROOT "curl -s https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh | bash"
		$CHROOT "papirus-folders -C bluegrey --theme Papirus-Dark"
		status
	fi
}


# installation complete
goodbye () {

	echo
	echo -e "\nInstallation complete."
	echo -e "\nAny key to reboot.."
	read -n1 -rs

	# unmount partions from /mnt
	umount -R /mnt

	# clean up installation files
	rm -rf -- "$(pwd)"

	reboot
}


# call main, parse script
main "$@"
