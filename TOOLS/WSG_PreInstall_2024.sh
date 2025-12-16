#!/bin/bash
# Program: 
#     It is system prepaer for Forcepoint WSG on S/W base Linux
#     CentOS 7 was EOS, modify yum repository.
# History:
# 2024-09-23: Test for WSG v8.5.6 on CentOS 7.9.2009(Core)

rm -rf /tmp/WSG_pre-install_log_$(date +%F).log
touch /tmp/WSG_pre-install_log_$(date +%F).log

# Check Network.
echo "$(date +%Y%m%d-%T) - Check Network."
read -p "Please input IP adress for eth0: " ipaddress
read -p "Please input default gateway's IP for eth0: " defaultgateway
ping -c 3 $defaultgateway 

if [ $? -eq 0 ]; then
 	echo "$(date +%Y%m%d-%T) - Ping default gateway OK." >> /tmp/WSG_pre-install_log_$(date +%F).log
 else 
 	echo "Fail to ping default gateway, please check your network setting."
 	exit 1
 fi 

curl http://ddsint.websense.com

if [ $? -eq 0 ]; then
	echo "$(date +%Y%m%d-%T) - DNS Chek OK." >> /tmp/WSG_pre-install_log_$(date +%F).log
else 
	echo "Name resolution failed, please check your DNS setting."
	exit 1
fi

# Setup Hostname

read -p "Please enter your hostname(FQDN): " os_hostname
hostnamectl set-hostname $os_hostname
sed -i "1i $ipaddress $os_hostname" /etc/hosts

# Setup NTP cron job.
read -p "Please enter NTP server: " ntpserver
crontab -l | { cat; echo "* */1 * * * /usr/sbin/ntpdate $ntpserver"; } | crontab -

# Disable Selinux.
echo ""
echo "$(date +%Y%m%d-%T) - Disable Selinux." >> /tmp/WSG_pre-install_log_$(date +%F).log
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config
set enforce 0

# Change yum config
/bin/mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo-ORG
cat <<EOF > "/etc/yum.repos.d/CentOS-Base.repo"
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-\$releasever - Base
#mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=os&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
baseurl=https://vault.centos.org/centos/\$releasever/os/\$basearch/
gpgcheck=0
enabled=1

#released updates
[updates]
name=CentOS-\$releasever - Updates
#mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=updates&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/
baseurl=https://vault.centos.org/centos/\$releasever/updates/\$basearch/
gpgcheck=0
enabled=1

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=extras&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/
baseurl=https://vault.centos.org/centos/\$releasever/extras/\$basearch/
gpgcheck=0
enabled=1

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
#mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=centosplus&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/centosplus/\$basearch/
baseurl=https://vault.centos.org/centos/\$releasever/centosplus/\$basearch/
gpgcheck=0
enabled=0
EOF

chmod 644 /etc/yum.repos.d/CentOS-Base.repo

# Pre-install needed services and packages.
yum update list

echo ""
echo "$(date +%Y%m%d-%T) -  Pre-install and enable needed services and packages." >> /tmp/WSG_pre-install_log_$(date +%F).log
for need_services in wget unzip telnet ntp openssh-clients net-tools bind-utils sysstat lsof pciutils tcpdump lynx  ; do
	yum install $need_services -y
	if [ $? -eq 0 ]; then
		echo "$(date +%Y%m%d-%T) - [$need_services] install seccussfully." >> /tmp/WSG_pre-install_log_$(date +%F).log
	else
		echo "$(date +%Y%m%d-%T) - [$need_services] install failed, please try again later." >> /tmp/WSG_pre-install_log_$(date +%F).log
	fi
done

# Pre-install for WSE
echo ""
echo "$(date +%Y%m%d-%T) - Pre-install for WSE" >> /tmp/WSG_pre-install_log_$(date +%F).log
for WSE in epel-release haveged iptables-services xorg-x11-fonts-Type1 dejavu-serif-fonts htop; do
	yum install $WSE -y
	if [ $? -eq 0 ]; then
		echo "$(date +%Y%m%d-%T) - [$WSE] install seccussfully." >> /tmp/WSG_pre-install_log_$(date +%F).log
	else
		echo "$(date +%Y%m%d-%T) - [$WSE] install failed, please try again later." >> /tmp/WSG_pre-install_log_$(date +%F).log
	fi
done

# Pre-install for WCG
echo ""
echo "$(date +%Y%m%d-%T) - Pre-install for WCG" >> /tmp/WSG_pre-install_log_$(date +%F).log
for WCG in apr apr-util at avahi-libs bc compat-db47 compat-db-headers cups-client cups-libs ed ftp gd gnutls krb5-libs krb5-workstation libicu libjpeg-turbo libkadm5 libldb libpcap libpng12 libtalloc libtdb libtevent libwbclient libX11 libX11-common libXau libxcb libXft libXpm libXrender m4 mailcap mailx ncurses-devel nettle nmap-ncat patch perl perl-autodie perl-Business-ISBN perl-Business-ISBN-Data perl-Carp perl-Compress-Raw-Bzip2 perl-Compress-Raw-Zlib perl-constant perl-Data-Dumper perl-Digest perl-Digest-MD5 perl-Encode perl-Encode-Locale perl-Exporter perl-File-Listing perl-File-Path perl-File-Temp perl-Filter perl-Getopt-Long perl-HTML-Parser perl-HTML-Tagset perl-HTTP-Cookies perl-HTTP-Daemon perl-HTTP-Date perl-HTTP-Message perl-HTTP-Negotiate perl-HTTP-Tiny perl-IO-Compress perl-IO-HTML perl-IO-Socket-IP perl-IO-Socket-SSL perl-libs perl-libwww-perl perl-LWP-MediaTypes perl-macros perl-Mozilla-CA perl-Net-HTTP perl-Net-LibIDN perl-Net-SSLeay perl-parent perl-PathTools perl-Pod-Escapes perl-podlators perl-Pod-Simple perl-Pod-Usage perl-Scalar-List-Utils perl-Socket perl-Storable perl-Switch perl-Text-ParseWords perl-threads perl-threads-shared perl-TimeDate perl-Time-HiRes perl-Time-Local perl-URI perl-WWW-RobotRules psmisc readline-devel redhat-lsb-core redhat-lsb-submod-security samba-client-libs samba-common samba-common-libs spax tcl time trousers; do
	yum install $WCG -y
	if [ $? -eq 0 ]; then
		echo "$(date +%Y%m%d-%T) - [$WCG] install seccussfully." >> /tmp/WSG_pre-install_log_$(date +%F).log
	else
		echo "$(date +%Y%m%d-%T) - [$WCG] install failed, please try again later." >> /tmp/WSG_pre-install_log_$(date +%F).log
	fi
done

# Enable / Disable needed services.
echo ""
echo "$(date +%Y%m%d-%T) - Enable / Disable needed services." >> /tmp/WSG_pre-install_log_$(date +%F).log
systemctl stop NetworkManager
systemctl disable NetworkManager
systemctl stop firewalld.service
systemctl disable firewalld.service
systemctl start iptables.service
systemctl enable iptables.service
systemctl start haveged.service
systemctl enable haveged.service

# OS optimization.
echo ""
echo "$(date +%Y%m%d-%T) - OS optimization." >> /tmp/WSG_pre-install_log_$(date +%F).log
echo "net.nf_conntrack_max=100000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_time=1200" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_intvl=180" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf

# Add iptables rules to allow policy server connection.
iptables -i eth0 -I INPUT -p tcp --dport 1024:65535 -j ACCEPT
iptables-save
iptables-save >> /etc/sysconfig/iptables

# WSGMA
cd /root
wget https://dl.docutek.biz/MK/wsg_ma.txt --no-check-certificate
/bin/mv /root/wsg_ma.txt /root/wsg_ma.sh && chmod 755 /root/wsg_ma.sh

echo "Please reboot your system."
exit 0
