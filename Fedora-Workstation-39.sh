#!/bin/bash

# Copyright (C) 2023 Thien Tran
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

# This is fork of tommytran732's fedora setup script. Many changes are made for my personal usage and you can easily make further changes as per your needs too. Most notable changes are explained here. You can check readme.md for more deatils on what has changed compared to tommy's setup script. 

# To run this script and create a log file of output. Type the command below in terminal
# ./Fedora-Workstation-39.sh | tee ./Fedora-Workstation-39.log

output(){
    echo 'Your Fedora Workstation is getting ready';
    echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
    sudo -u nobody "$@"
}

# Moving to the home directory

cd /home/"${USER}" || exit

# Setting umask to 077 and making home directory private

umask 077
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc
echo 'umask 077' | sudo tee -a /etc/bashrc
chmod 700 /home/*

# Compliance changes

sudo systemctl mask ctrl-alt-del.target
sudo systemctl mask debug-shell.service
sudo systemctl mask kdump.service
echo 'CtrlAltDelBurstAction=none' | sudo tee -a /etc/systemd/system.conf

# Arkenfox setup
# Please install uBlock origin by yourself and enable AdGuard URL Tracking Protection Filter along with https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt

unpriv curl https://raw.githubusercontent.com/arkenfox/user.js/master/user.js | sudo tee /usr/lib/firefox/browser/default/preferences/user.js

# Setup NTS using GrapheneOS Chrony Configuration because it's quite solid as it makes use of over 4 different pools and it's encrypted

sudo rm -rf /etc/chrony/chrony.conf
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf
echo '#Command-line options for chronyd
OPTIONS="-F 1"' | sudo tee /etc/sysconfig/chronyd
sudo systemctl restart chronyd

# Enabled DNSSEC in resolv.conf because by default it is disabled

unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/systemd/resolved.conf.d/resolv.conf | sudo tee /usr/lib/systemd/resolved.conf.d/resolv.conf

# Setup Networking and enable mac randomization

unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/NetworkManager/conf.d/00-macrandomize.conf | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf
unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/NetworkManager/conf.d/01-transient-hostname.conf | sudo tee /etc/NetworkManager/conf.d/01-transient-hostname.conf

sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''
sudo firewall-cmd --set-default-zone=block
sudo firewall-cmd --permanent --add-service=dhcpv6-client
sudo firewall-cmd --reload
sudo firewall-cmd --lockdown-on

# Harden SSH by turning off X11 forwarding, making use of ONLY ed22519 keys, setting cipher to aes256-gcm@openssh.com, disabling password authentication and root login

#echo 'PermitRootLogin no' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
#echo 'GSSAPIAuthentication no' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf

unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/ssh/sshd_config/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
echo 'VerifyHostKeyDNS yes' | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf

# Security kernel settings

unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf | sudo tee /etc/sysctl.d/990-security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf | sudo tee /etc/sysctl.d/30_silent-kernel-printk.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf | sudo tee /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=1/g' /etc/sysctl.d/990-security-misc.conf
sudo grubby --update-kernel=ALL --args='spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt tsx=off tsx_async_abort=full,nosmt kvm.nx_huge_pages=force nosmt=force l1d_flush=on mmio_stale_data=full,nosmt random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=isolation_force efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on extra_latent_entropy debugfs=off'
(sudo dracut -f; sudo sysctl -p)

# Systemd Hardening

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo sh -c 'systemctl restart NetworkManager && systemctl restart irqbalance'

unpriv curl https://gitlab.com/divested/brace/-/blob/master/brace/usr/lib/systemd/system/tor.service.d/99-brace.conf | sudo tee /etc/systemd/system/tor.service.d/99-brace.conf

# Disable automount

unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/dconf/db/local.d/automount-disable | sudo tee /etc/dconf/db/local.d/automount-disable
unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/dconf/db/local.d/locks/automount-disable | sudo tee /etc/dconf/db/local.d/locks/automount-disable

sudo dconf update

# Setup ZRAM
echo -e '[zram0]\nzram-fraction = 1\nmax-zram-size = 8192\ncompression-algorithm = zstd' | sudo tee /etc/systemd/zram-generator.conf

# Speed up DNF
unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/dnf/dnf.conf | sudo tee /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Remove firefox packages
sudo dnf -y remove fedora-bookmarks fedora-chromium-config firefox mozilla-filesystem

# Remove Network + hardware tools packages
sudo dnf -y remove '*cups' nmap-ncat nfs-utils nmap-ncat openssh-server net-snmp-libs net-tools opensc traceroute rsync tcpdump teamd geolite2* mtr dmidecode sgpio

# Remove support for some languages and spelling
sudo dnf -y remove ibus-typing-booster '*speech*' '*zhuyin*' '*pinyin*' '*kkc*' '*m17n*' '*hangul*' '*anthy*' words

# Removes codec + image + printers 
sudo dnf -y remove openh264 ImageMagick* sane* simple-scan

# Remove Active Directory + Sysadmin + reporting tools
sudo dnf -y remove 'sssd*' realmd adcli cyrus-sasl-plain cyrus-sasl-gssapi mlocate quota* dos2unix kpartx sos abrt samba-client gvfs-smb

# Remove Virtual Machine and VM stuff. if you need any in the future you can reinstall them
sudo dnf -y remove 'podman*' '*libvirt*' 'open-vm*' qemu-guest-agent 'hyperv*' spice-vdagent virtualbox-guest-additions vino xorg-x11-drv-vmware xorg-x11-drv-amdgpu

# Remove NetworkManager Packages
sudo dnf -y remove NetworkManager-pptp-gnome NetworkManager-ssh-gnome NetworkManager-openconnect-gnome NetworkManager-openvpn-gnome NetworkManager-vpnc-gnome ppp* ModemManager

# Remove all the Gnome apps which you don't need here
sudo dnf remove -y gnome-photos gnome-connections gnome-tour gnome-themes-extra gnome-screenshot gnome-remote-desktop gnome-font-viewer gnome-calculator gnome-calendar gnome-contacts \
    gnome-maps gnome-weather gnome-logs gnome-boxes gnome-disk-utility gnome-clocks gnome-color-manager gnome-characters baobab totem \
    gnome-shell-extension-background-logo gnome-shell-extension-apps-menu gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list \
    gnome-classic* gnome-user* chrome-gnome-shell eog

# Remove packages and apps that I don't use 
sudo dnf remove -y rhythmbox yelp evince libreoffice* cheese file-roller* lvm2 rng-tools thermald '*perl*' yajl

# Disable openh264 Repository and Third-Party repositories including everything from flathub.org, google-chrome, phracek-PyCharm, rpmfusion-nonfree-steam
# You can enable any repository later by going in store settings later
sudo dnf config-manager --set-disabled fedora-cisco-openh264 flathub google-chrome phracek-PyCharm rpmfusion-nonfree-steam

# gnome-console here will replace gnome-terminal and there are other packages I use on my Fedora workstation. You can add more packages from fedora repositery in the above line.

sudo dnf -y install gnome-console git-core gnome-shell-extension-appindicator gnome-shell-extension-blur-my-shell gnome-shell-extension-background-logo gnome-shell-extension-dash-to-dock gnome-shell-extension-no-overview

# Install LibreWolf or Brave Browser or Both

echo 'Note: Use of a single browser is recommended because of higher attack surface of a browser. Firefox is already configured by default. You will have to add uBlock by yourself. if you choose other browsers like Brave then make sure to harden it by yourself because it will be set to default unlike librewolf/firefox which is already configured. \n'

read -n -p "Enter '1' for Librewolf. Enter '2' for Brave Browser. Enter '3' for both LibreWolf and Brave Browser. Enter 0 to skip: " browser

case $browser in
    
    "1")
    output 'Installing LibreWolf as your browser of choice.'
    sudo rpm --import https://keys.openpgp.org/vks/v1/by-fingerprint/034F7776EF5E0C613D2F7934D29FBD5F93C0CFC3
    sudo dnf config-manager --add-repo https://rpm.librewolf.net/librewolf-repo.repo
    sudo dnf install librewolf -y
    output 'LibreWolf has been successfully installed on your system'
    ;;
    
    "2")
    output 'Installing Brave Browser as your browser of choice.'
    sudo dnf install dnf-plugins-core
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    sudo dnf install brave-browser
    output 'Brave Browser has been successfully installed on your system'
    ;;
    
    "3")
    output 'Installing LibreWolf & Brave Browser as your primary browsers.'
    sudo rpm --import https://keys.openpgp.org/vks/v1/by-fingerprint/034F7776EF5E0C613D2F7934D29FBD5F93C0CFC3
    sudo dnf config-manager --add-repo https://rpm.librewolf.net/librewolf-repo.repo
    sudo dnf install librewolf -y
    sudo dnf install dnf-plugins-core
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    sudo -- sh -c 'dnf install librewolf -y; dnf install brave-browser y'
    output 'LibreWolf & Brave Browser have been successfully installed on your system'
    ;;
    
    *)
    output 'No browser is being installed as per your previous input'
    ;;

esac

# Enable auto TRIM
# Fstrim is used on a mounted file system to optimize the performance and lifetime of SSDs by minimizing write amplification and deleting data.

sudo systemctl enable fstrim.timer

# The Linux Vendor Firmware Service is a secure portal which allows hardware vendors to upload firmware updates.

unpriv curl https://raw.githubusercontent.com/sky768/Fedora-Workstation-39/master/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/.conf
sudo systemctl restart fwupd

# Differentiating bare metal and virtual installs
# Installing tuned first here because virt-what is 1 of its dependencies anyways

sudo dnf install tuned -y

virt_type=$(virt-what)
if [ "$virt_type" = '' ]; then
    output 'Virtualization: Bare Metal.'
elif [ "$virt_type" = 'openvz lxc' ]; then
    output 'Virtualization: OpenVZ 7.'
elif [ "$virt_type" = 'xen xen-hvm' ]; then
    output 'Virtualization: Xen-HVM.'
elif [ "$virt_type" = 'xen xen-hvm aws' ]; then
    output 'Virtualization: Xen-HVM on AWS.'
else
    output "Virtualization: $virt_type."
fi

# Setup tuned

if [ "$virt_type" = '' ]; then
  sudo dnf remove tuned -y
else
  sudo tuned-adm profile virtual-guest
fi

# Add Divested Third-Party Respositery

unpriv curl https://gitlab.com/divested/divested-release/-/jobs/5719496502/artifacts/file/build/noarch/divested-release-20231210-2.noarch.rpm
sudo dnf install divested-release-20231210-2.noarch.rpm -y

# Install divested firejail which has over 1200+ profiles already made. Making path in home directory ~/.config/firejail/ for adding further changes per app by making .local firejail files

sudo dnf install firejail -y
mkdir -p ~/.config/firejail/

# Install Divested Unofficial hardened_malloc

read -n -p "Type '1' if you want to install hardened_malloc from divest (Note: hardened_malloc can cause breakage on some apps) Skip by typing '0' if you're not sure" malloc

MACHINE_TYPE=$(uname -m)
if [$malloc==1]
then
    sudo dnf install -y hardened_malloc # The current default is set to memefficient. You can change it later if you'd like or build it yourself. Check out https://github.com/divestedcg/rpm-hardened_malloc
    eecho -e "blacklist /etc/ld.so.preload" > ~/.config/firejail/firefox.local # You can remove this line if you're not using firefox. it's added because FF crashes or doesn't load on a system with hardened_malloc
fi

# Install Divested real-ucode 
if [ "$virt_type" = '' ];
then
    sudo dnf install 'https://divested.dev/rpm/fedora/divested-release-20230406-2.noarch.rpm';
    sudo sed -i 's/^metalink=.*/&?protocol=https/g' /etc/yum.repos.d/divested-release.repo;
    sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware;
    sudo dnf install real-ucode;
    sudo dracut -f;
    exit 0;
fi

# Enabling automatic updates


if [ -f /etc/fedora-release ];
then
	output 'Enabling automatic updates';
	dnf install dnf-automatic rpm-plugin-systemd-inhibit;
	systemctl enable dnf-automatic-install.timer --now;
    exit 0;
fi;

# Remove gnome-terminal becauase gnome-console will replace it 

sudo dnf remove gnome-terminal -y

#keeping gnome-text-editor and mediawriter, librewolf or Brave as the only choices of browsers (Firefox will be already installed), hardened_malloc if x86_64/aarch64, Firejail, TODO: Add tor-browser required packages