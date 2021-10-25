## Arch Xfce Hardened - (Arch-X)

### About

I made this [Arch Linux](https://archlinux.org/) installer for my own personal use, but it could work for anyone who wants a lightweight hardened system that works and looks good out of the box.

To change which apps are installed you can add or remove them from the [packages](https://github.com/kuladog/arch-xfce-hardened/blob/main/packages) script. Dotfiles and configuration files can be edited, added, or removed from the `etc`, `skel`, and `usr` directories. And, of course, read through the [install script](https://github.com/kuladog/arch-xfce-hardened/blob/main/install.sh) to make sure it's gonna do what you want.

![alt text](screen.png "Arch Xfce")

### Usage

From the [Archiso](https://archlinux.org/download/) live environment, clone this repo with one of the following options and run the install script.
 
1. Using curl: (included in archiso)
```sh
curl -LO https://github.com/kuladog/arch-xfce-hardened/archive/main.zip

bsdtar xf main.zip

cd arch-xfce-hardened-main

bash install.sh
```

2. Using git: (need to install)
```sh
pacman -Syy

pacman install git

git clone https://github.com/kuladog/arch-xfce-hardened.git

cd arch-xfce-hardened

bash install.sh
```

### Disclaimer

This was just a fun project to get some bash time in... and kill off some pandemic boredom. As a general use installer it has limitations, but it does what it's supposed to do—for me—perfectly. :smiley:
