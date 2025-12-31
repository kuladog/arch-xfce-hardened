#!/usr/bin/env bash

#  install.sh
#
#  Hardened Arch + XFCE Installer
#  Revised: 2025-12-15
#

set -euo pipefail
IFS=$'\n\t'

DIR=$(dirname "${BASH_SOURCE[0]}")

exec > >(tee /var/log/arch-xfce-setup.log) 2>/dev/tty

banner() {
	clear; cat <<- EOF



               AA
              AA  A                        hh             xx    xx
             AA   AA                       hh              xx  xx
            AA     AA     rr rrr    cccc   hhhhh             xx
           AA  AAA  AA    rrr     cc       hh   hh   ===    xxx
          AA         AA   rr      cc       hh   hh         xx  xx
         AA           AA  rr        cccc   hh   hh        xx    xx


                ARCH LINUX - XFCE - HARDENED - by Kuladog



EOF
}

chroot() { arch-chroot /mnt bash -c "$*"; }

status() { echo -e "\e[0;32m Success!\e[0m"; }

flush() { tput cr; tput el; }

#================================================
#    USER PROMPTS
#================================================

user_confirm() {
	flush; read -rp $'\n  You\'re about to install Arch Linux (Hardened). Proceed? [Y/n]: '
	confirm="${REPLY:-y}"

	if [[ ! $confirm =~ ^[Yy]$ ]]; then
		echo -e "\nInstall aborted."
		exit 0
	fi
}

user_passwords() {
	local login="$1"
	local p1 p2

    while true; do
		flush; read -rsp "Choose $login password: " p1; echo
		flush; read -rsp "Retype $login password: " p2; echo
		[[ $p1 == "$p2" ]] && break
		echo -e "\nPasswords don't match, try again .."
	done

	[[ $login = root ]] && ROOTPASS="root:$p1" || USERPASS="$login:$p1"
}

user_namespace() {
	flush; read -rp $'\nChoose hostname > '; HOST="${REPLY:-archx}"
    flush; read -rp $'\nChoose username > '; NAME="${REPLY:-user}"

    echo && user_passwords root
    echo && user_passwords "$NAME"
}

#================================================
#    DISK MANAGEMENT
#================================================

disk_select() {
	echo -e "\nAvailable disks:"
	sfdisk -l | grep -E 'Lable|Type|Size|nvme|sd|hd|vd'

    while true; do
		flush; read -rp $'\nDisk: /dev/' DISK
		DEVICE="/dev/${DISK,,}"
        [[ -b $DEVICE ]] && break
        echo "Invalid disk."
    done
}

disk_partition() {
    echo -e "\nPartitioning $DEVICE ..."

    if sfdisk -l "$DEVICE" | grep -q gpt; then
        sfdisk "$DEVICE" <<EOF >/dev/null
label: gpt
unit: sectors
${DEVICE}1 : start=2048, size=2099199, type=ef
${DEVICE}2 : start=2099200, size=+, type=83
EOF
    else
        sfdisk "$DEVICE" <<EOF >/dev/null
label: mbr
unit: sectors
${DEVICE}1 : start=2048, size=+, type=83
EOF
    fi
	status
}

disk_format() {
	while true; do
		echo -e "\nChoose filesystem (ext4, btrfs, xfs)"
		flush; read -rp " > " fstype
        [[ $fstype =~ ^(ext[234]|btrfs|xfs)$ ]] && break
        echo "Invalid filesystem."
    done

	echo -e "\nFormating partitions ..."
    if sfdisk -l "$DEVICE" | grep -q gpt; then
        mkfs.fat -F32 "${DEVICE}1" >/dev/null
        mkfs."$fstype" "${DEVICE}2" >/dev/null
    else
        mkfs."$fstype" "${DEVICE}1" >/dev/null
    fi
	status
}

disk_mount() {
    echo -e "\nMounting partitions ..."

    mkdir -p /mnt

    if sfdisk -l "$DEVICE" | grep -q gpt; then
		mkdir -p /mnt/{,boot}
		mount "${DEVICE}2" /mnt
		mount "${DEVICE}1" /mnt/boot
    else
        mount "${DEVICE}1" /mnt
    fi
	status
}

#================================================
#    PACKAGE MANAGEMENT
#================================================

install_system() {
	echo -e "\nInstalling system packages ..."

    if [[ -f ${DIR}/packages ]]; then
		source "${DIR}/packages"
		pacstrap -K /mnt "${INSTALL[@]}"
		status
	else
		echo -e "\nError: 'packages' file not found."
	fi
}

install_vdagent() {
	if [[ $(systemd-detect-virt) != none ]]; then
		echo -e "\nInstalling guest agents ..."
		pacstrap -K /mnt qemu-guest-agent spice-vdagent
		status
	fi
}

install_theme() {
	local theme_dir="/mnt/home/${NAME}/.themes"

	curl -LO https://github.com/kuladog/adwaita-grey-dark/archive/refs/heads/main.zip

	if [[ -f ${DIR}/main.zip ]]; then
		echo -e "\nSetting desktop theme ..."

		bsdtar xf main.zip
		mkdir -p "$theme_dir"
		mv ./*grey-dark* "${theme_dir}"/Adwaita-grey-dark
		status
	fi
}

install_icons() {
	echo -e "\nSetting desktop icons ..."

	pacstrap -K /mnt wget papirus-icon-theme

	chroot "curl -s https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh | bash"
	chroot "papirus-folders -C black --theme Papirus-Dark"
	status
}

#================================================
#    SYSTEM CONFIGURATION
#================================================

sys_accounts() {
	echo -e "\nSetting hostname ..."
	echo "$HOST" > /mnt/etc/hostname
	status

	echo -e "\nSetting root password ..."
	echo "$ROOTPASS" | chroot "chpasswd"
	status

	echo -e "\nCreating new user '$NAME' ..."
	chroot "useradd -mG wheel -s /bin/bash $NAME"
	status

	echo -e "\nSetting ${NAME}'s password ..."
	echo "$USERPASS" | chroot "chpasswd"
	status
}

sys_configs() {
    echo -e "\nCopying configuration files ..."

	if [[ -d ${DIR}/configs ]]; then
		find "${DIR}/configs" -type f | while read -r file; do
			dest="/mnt/etc/${file#${DIR}/configs/}"
			mkdir -p "$(dirname "$dest")"
			sed -e "s|<user>|${NAME}|" -e "s|<host>|${HOST}|" "$file" > "$dest"
		done
		status
	fi

	chroot "chown -R root:root /etc"
}

sys_fstab() {
	echo -e "\nConfiguring filesystem table ..."

	local fstab=/mnt/etc/fstab

	if genfstab -U /mnt >> "$fstab"; then
		sed -i \
		-e '/boot/ s=relatime=noatime=' \
		-e '/\/[[:space:]]/ s=relatime=noatime=' \
		-e '/home\|var/ s=defaults=noatime,nodev,nosuid=' \
		-e 's/\S\+/0/5' \
		-e 's/\S\+/0/6' \
		"$fstab"

		{
		echo "tmpfs /tmp        tmpfs   nodev,nosuid,noexec 0 0"
		echo "tmpfs /var/tmp    tmpfs   nodev,nosuid,noexec 0 0"
		echo "tmpfs /dev/shm    tmpfs   nodev,nosuid,noexec 0 0"
		} >> "$fstab"
	fi
	status
}

sys_grub() {
    echo -e "\nInstalling GRUB ..."

    if sfdisk -l "$DEVICE" | grep -q gpt; then
        chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
    else
        chroot "grub-install --target=i386-pc $DEVICE"
    fi

    chroot "grub-mkconfig -o /boot/grub/grub.cfg"
    status
}

#================================================
#    CONFIGURE SERVICES
#================================================

svc_enable() {
	for s in apparmor chronyd systemd-resolved NetworkManager firewalld lxdm; do
		echo -e "\nEnabling $s ..."
		chroot "systemctl list-unit-files | grep -q $s" || continue
		chroot "systemctl enable $s"
		status
	done
}

svc_firewall() {
	RULESET=(
		--set-default-zone=drop
		--add-service=https
		--add-icmp-block-inversion
		)

	if chroot "command -v firewalld" &>/dev/null; then
		echo -e "\nConfiguring Firewalld ...\n"

		chroot "systemctl start firewalld"

		for r in "${RULESET[@]}"; do
			chroot "firewall-offline-cmd $r"
		done
		status
	fi
}

svc_firejail() {
	if chroot "command -v firejail" &>/dev/null; then
		echo -e "\nConfiguring Firejail ...\n"

		chroot "groupadd firejail || true"
		chroot "usermod -aG firejail $NAME"
		chroot "chown root:firejail /usr/bin/firejail"
		chroot "chmod 4750 /usr/bin/firejail"
		chroot "firecfg"
		status
	fi
}

#================================================
#    USER DIRECTORY
#================================================

user_dotfiles() {
	echo -e "\nCopying dotfiles ..."

	mkdir -p /mnt/home/"${NAME}"/{Documents,Downloads,Projects,.aur}

	if [[ -d ${DIR}/dotfiles ]]; then
		find "${DIR}/dotfiles" -type f | while read -r file; do
			dest="/mnt/home/${NAME}/${file#${DIR}/dotfiles/}"
			mkdir -p "$(dirname "$dest")"
			sed -e "s|<user>|${NAME}|" "$file" > "$dest"
		done
		status
	fi
}

user_permissions() {
	echo -e "\nSetting permissions ..."

	chroot "chown -R $NAME:$NAME /home/$NAME"
	chroot "chmod -R 750 /home/$NAME"
	status
}

user_no_recents() {
	echo -e "\nDisabling recent files ..."

	local recent="/mnt/home/${NAME}/.local/share/recently-used.xbel"

	truncate -s 0 "$recent"
	chattr +i "$recent" 2>/dev/null || true
	status
}

#================================================
#    SETUP COMPLETE
#================================================

finish() {
	clear
	echo -e "\n Setup complete!\n\n Press any key to reboot..."
	read -n 1 -rs

	rm -rf ../{arch-xfce*,*main.zip}

	umount -R /mnt
	reboot
}

main() {
	banner
	user_confirm
	user_namespace

	disk_select
	disk_partition
	disk_format
	disk_mount

	install_system
	install_vdagent
	install_theme
	install_icons

	sys_accounts
	sys_configs
	sys_fstab
	sys_grub

	svc_enable
	svc_firewall
	svc_firejail

	user_dotfiles
	user_permissions
	user_no_recents

	finish
}

main "$@"
