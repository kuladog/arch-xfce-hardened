#!/usr/bin/env bash

#  install.sh
#
#  A simple bash script to set up a bare-bones, hardened, and user-friendly Arch box.
#
#  Repo: github.com/kuladog/arch-xfce-hardened
#  Revised: 2025-11-12
#

set -euo pipefail
IFS=$'\n\t'

SOURCE=$(dirname "${BASH_SOURCE[0]}")

exec > >(tee /var/log/arch-xfce-setup.log) 2>/dev/tty

clear

main () {
	greeter
	user_confirm
	user_prompt
## Disk Management
	select_disk
	partition_disk
	format_disk
	mnt_partitions
## Package Management
	install_pkgs
	paprius_theme
## System Configuration
	sys_credentials
	copy_configs
	grub_config
	make_fstab
## Configure Services
	enable_services
	firewall_config
	firejail_config
## Login Directory
	copy_dotfiles
	home_permissions
	no_recents
	goodbye
}

greeter() {
    cat <<- EOF


               AA
              AA  A                        hh             xx    xx
             AA   AA                       hh              xx  xx
            AA     AA     rr rrr    cccc   hhhhh             xx
           AA  AAA  AA    rrrr    cc       hh   hh   ===    xxx
          AA         AA   rr      cc       hh   hh         xx  xx
         AA           AA  rr        cccc   hh   hh        xx    xx


                ARCH LINUX - XFCE - HARDENED - by Kuladog



	EOF
	}

chroot() { arch-chroot /mnt bash -c "$*"; }

flush() { sleep 0.01; }

status() {
		local red='\033[0;33m'
		local grn='\033[0;32m'
		local nc='\033[0m'

		if [[ $? -eq 0 ]]; then
			echo -e "${grn} Success!${nc}"
		else
			echo -e "${red} Operation failed.${nc}"
		fi
	}

user_confirm() {
        echo -e "\n\n  You're about to install Arch Linux (Hardened). Is this OK? [Y/n] "
        read -rs confirm
		confirm=${confirm:-Y}

		if [[ ! $confirm =~ ^[Yy]$ ]]; then
		  echo -e "\n Setup aborted."
		  exit 0
		fi
    }

set_passwd() {
		local login="$1"

		newpass() {
			flush; read -rp " Choose password for '${login}': " PASS1
			flush; read -rp " Retype password for '${login}': " pass2
		}

		newpass
		while [[ $PASS1 != "$pass2" ]]; do
			echo -e "\n Passwords don't match, try again .."
			newpass
		done

		if [[ $login = root ]]; then
			ROOTPASS="root:${PASS1}"
		else
			USERPASS="${login}:${PASS1}"
		fi
	}

user_prompt() {
		echo -e "\n\n Choose a system hostname:"
		flush; read -rp " >  " HOST
		HOST=${HOST:-archx}

		flush; echo && set_passwd root

		echo -e "\n Choose a user name:"
		flush; read -rp " >  " NAME
		NAME=${NAME:-user}

		flush; echo && set_passwd "$NAME"
	}

#================================================
#    DISK MANAGEMENT
#================================================

select_disk() {
		echo -e "\n\n Available drive(s) to install on: \n"
		fdisk -l | grep -E 'Label|Size|nvme|sd|hd|vd'

		echo -e "\n Enter the device name: (eg. nmve0n1, sdc, vda)"
		flush; read -rp " Disk /dev/" DISK

		local available=($(lsblk | grep -E "^[svhdnvme]+[0-9]?"))
		while [[ ! ${available[@]} =~ ${DISK,,} ]]; do
				echo -e "\n Disk '${DISK}' not available, try again."
				flush; read -rp "Disk /dev/" DISK
			done

		DEVICE=/dev/"${DISK,,}"
	}

partition_disk() {
		echo -e "\n Creating new partitions ...\n"

		if fdisk -l "${DEVICE}" | grep -q gpt; then
			sfdisk "${DEVICE}" >/dev/null <<EOF
label: gpt
unit: sectors

"${DEVICE}"1 : start=2048, size=2099199, type=ef
"${DEVICE}"2 : start=2099200, size=+, type=83
EOF
		else
			sfdisk "${DEVICE}" >/dev/null <<EOF
label: mbr
unit: sectors

"${DEVICE}"1 : start=2048, size=+, type=83
EOF
		fi
		lsblk "${DEVICE}"
		status
}

format_disk() {
    PARTITION=$(lsblk "$DEVICE" | grep -c part)

    while true; do
        echo -e "\n Choose a filesystem for new partitions: (eg. ext4, btrfs, xfs)"
        flush; read -rp " >  " fstype

        if [[ $fstype =~ ^(ext[234]|btrfs|xfs)$ ]]; then
			echo -e "\n Formating new partitions ..."
            if fdisk -l "${DEVICE}" | grep -q gpt; then
                mkfs.fat -F32 "${DEVICE}1" >/dev/null
            else
                for part in $(seq 1 "$PARTITION"); do
                    mkfs."$fstype" "${DEVICE}${part}" >/dev/null
                done
            fi
            status
            break
        else
            echo -e "\n Invalid filesystem. Try again ..."
        fi
    done
}

mnt_partitions() {
		echo -e "\n Mounting new partitions ..."

		if fdisk -l "$DEVICE" | grep -q dos; then
			mkdir -p /mnt
			mount "${DEVICE}1" /mnt
		else
			case $PARTITION in
				3)
					mkdir -p /mnt/home
					mount "${DEVICE}3" /mnt/home
					;&
				2)
					mkdir -p /mnt/{,boot}
					mount "${DEVICE}2" /mnt
					mount "${DEVICE}1" /mnt/boot
					;;
				*)
					;;
			esac
		fi
		status
	}

#================================================
#    PACKAGE MANAGEMENT
#================================================

install_pkgs() {
		PACKAGES=(Xorg Xfce Apps All None)

		echo -e "\n Arch 'Base' system will be installed, select additional packages: \n"
		for pkg in "${!PACKAGES[@]}"; do
			printf "%2d) %s\n" $((pkg+1)) "${PACKAGES[${pkg}]}"
		done

		echo
		flush; read -rp " >  " select

		local install=($(echo "$select" | tr -d '[:space:]' | grep -o .))

		if [[ -f ${SOURCE}/packages ]]; then
			source "${SOURCE}/packages" 0 "$install"
		else
			echo " ERROR: Source 'packages' not found."
			exit 1
		fi
	}

paprius_theme() {
		if chroot "command -v xfdesktop" &>/dev/null; then

			echo -e "\n Setting desktop and icon theme ..."

			pacstrap /mnt papirus-icon-theme
			chroot "
				curl -s https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh | bash && \
				papirus-folders -C bluegrey --theme Papirus-Dark
			"
			status
		fi
	}

#================================================
#    SYSTEM CONFIGURATION
#================================================

sys_credentials() {
		echo -e "\n Setting hostname ..."
		echo "$HOST" > /mnt/etc/hostname
		status

		echo -e "\n Setting 'root' password ..."
		chroot "echo '${ROOTPASS}' | chpasswd"
		status

		echo -e "\n Creating new user '$NAME' ..."
		chroot "useradd -mG wheel -s /bin/bash '$NAME'"
		status

		echo -e "\n Setting '$NAME' password ..."
		chroot "echo '${USERPASS}' | chpasswd"
		status
	}

copy_configs() {
		echo -e "\n Copying configuration files ..."

		if [[ -d ${SOURCE}/configs ]]; then
			find  "${SOURCE}"/configs -type f -exec sed -i -e "s|<user>|${NAME}|" \
			-e "s|<host>|${HOST}|" {} \;
			cp -raf configs/. /mnt/etc
			status
		fi

		chroot "chown -R 'root:root' /etc"
	}

grub_config() {
		echo -e "\n Generating grub configuration ..."

		if fdisk -l "$DEVICE" | grep -q gpt; then
			chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
		else
			chroot "grub-install --target=i386-pc '$DEVICE'"
		fi

		chroot "grub-mkconfig -o /boot/grub/grub.cfg"
	}

make_fstab() {
		echo -e "\n Configuring filesystem table ..."

		local fstable=/mnt/etc/fstab

		if genfstab -U /mnt >> "$fstable"; then
			sed -i \
			-e '/boot/ s=relatime=noatime=' \
			-e '/\/[[:space:]]/ s=relatime=noatime=' \
			-e '/home\|var/ s=defaults=noatime,nodev,nosuid=' \
			-e 's/\S\+/0/5' \
			-e 's/\S\+/0/6' \
			"$fstable"

			{
			echo "tmpfs /tmp        tmpfs   nodev,nosuid,noexec 0 0"
			echo "tmpfs /var/tmp    tmpfs   nodev,nosuid,noexec 0 0"
			echo "tmpfs /dev/shm    tmpfs   nodev,nosuid,noexec 0 0"
			echo "proc  /proc       proc    nodev,nosuid,noexec 0 0"
			} >> "$fstable"
		fi

		status
	}

#================================================
#    CONFIGURE SERVICES
#================================================

enable_services() {

		service=(
			apparmor
			chronyd
			firewalld
			lxdm
			NetworkManager
			reflector
			)

		for srv in "${service[@]}"; do
			if chroot "systemctl list-unit-files | grep -q '$srv'"; then
				echo -e "\n Enabling $srv ..."
				chroot "systemctl enable '$srv'"
				status
			fi
		done
	}

firewall_config() {

		ruleset=(
			--set-default-zone=drop
			--remove-forward
			--add-icmp-block-inversion
			)

		if chroot "command -v firewalld" &>/dev/null; then
			echo -e "\n Configuring Firewalld ...\n"

			chroot "systemctl start firewalld"

			for rule in "${ruleset[@]}"; do
				chroot "firewall-offline-cmd '$rule'"
			done
		fi
	}

firejail_config() {
		echo -e "\n Configuring Firejail ...\n"

		if chroot "command -v firejail" &>/dev/null; then

			chroot "
				groupadd firejail || true && \
				usermod -aG firejail '$NAME' && \
				chown root:firejail /usr/bin/firejail && \
				chmod 4750 /usr/bin/firejail && \
				firecfg
			"
			status
		fi
	}

#================================================
#    LOGIN DIRECTORY
#================================================

copy_dotfiles() {
		mkdir -p /mnt/home/"${NAME}"/{Documents,Downloads,Projects,.aur}

		echo -e "\n Copying user's dotfiles ..."
		if [[ -d ${SOURCE}/dotfiles ]]; then
			find "${SOURCE}"/dotfiles/ -type f -exec sed -i -e "s|<user>|${NAME}|" {} \;
			cp -rf dotfiles/. /mnt/home/"${NAME}"
			status
		fi
	}

home_permissions() {
		echo -e "\n Setting /home/* permissions ..."

		chroot "
			chown -R '${NAME}:${NAME}' /home/${NAME} && \
			chmod -R 0750 /home/${NAME}
		"
		status
	}

no_recents() {
		echo -e "\n Disabling recently-used files ..."

		local recent="/mnt/home/${NAME}/.local/share/recently-used.xbel"

		truncate -s 0 "$recent"

		if [[ -f $recent ]]; then
			chattr +i "$recent"
			status
		fi
	}

#================================================
#    SETUP COMPLETE
#================================================

goodbye() {
		echo -e "\nSetup complete! Press any key to reboot..."
		read -n 1 -rs

		rm -rf ../{arch-xfce*,*main.zip}

		umount -R /mnt
		reboot
	}

main "$@"
