#!/bin/bash
# Program: 
#     It is system prepaer for Forcepoint WSG on S/W base Linux
# History:
# 2025-12-09: Test for WSG v8.5.7 on OracleLinux 8.10

rm -rf /tmp/WSG_pre-install_log_$(date +%F).log
touch /tmp/WSG_pre-install_log_$(date +%F).log

# Modify Network.
## Interactive Network Interface Static IP Configuration Tool for Oracle Linux 8.10
echo "Oracle Linux 8.10 Network Interface Static IP Configuration Tool"

## Initial confirmation
read -p "Do you want to modify network interface settings? (y/N): " CONTINUE
if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "Skip network interface configuration."
	
    # Ask minimal info only for later checks
    read -p "Enter current IP address for this host (for /etc/hosts): " IPADDR
    read -p "Enter default gateway IP (for connectivity check): " GATEWAY
	else

read -p "Enter network interface name (e.g., eth0, eth1, enp0s3): " INTERFACE

CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$INTERFACE"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

## Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    echo "Check available interfaces with: ls /etc/sysconfig/network-scripts/ifcfg-*"
    exit 1
fi

echo "Found config file: $CONFIG_FILE"

## Backup original file
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Backup created: $BACKUP_FILE"

## Interactive input for static IP parameters (empty = skip)
read -p "Enter static IP address (e.g., 192.168.1.100, empty=skip): " IPADDR
read -p "Enter subnet mask (e.g., 24 , empty=skip): " PREFIX
read -p "Enter default gateway (e.g., 192.168.1.1, empty=skip): " GATEWAY
read -p "Enter primary DNS (e.g., 8.8.8.8, empty=skip): " DNS1
read -p "Enter secondary DNS (optional, empty=skip): " DNS2 && echo

## Change BOOTPROTO to static
sed -i 's/^BOOTPROTO=.*/BOOTPROTO=static/' "$CONFIG_FILE"

## Update only provided parameters
[[ -n "$IPADDR" ]] && sed -i "/^IPADDR=/d" "$CONFIG_FILE" && echo "IPADDR=$IPADDR" >> "$CONFIG_FILE"
[[ -n "$PREFIX" ]] && sed -i "/^PREFIX=/d" "$CONFIG_FILE" && echo "PREFIX=$PREFIX" >> "$CONFIG_FILE"
[[ -n "$GATEWAY" ]] && sed -i "/^GATEWAY=/d" "$CONFIG_FILE" && echo "GATEWAY=$GATEWAY" >> "$CONFIG_FILE"
[[ -n "$DNS1" ]] && sed -i "/^DNS1=/d" "$CONFIG_FILE" && echo "DNS1=$DNS1" >> "$CONFIG_FILE"
[[ -n "$DNS2" ]] && sed -i "/^DNS2=/d" "$CONFIG_FILE" && echo "DNS2=$DNS2" >> "$CONFIG_FILE"

echo "=== Updated Configuration ==="
cat "$CONFIG_FILE"

## Apply changes
read -p "Apply changes and restart $INTERFACE? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    # Delete old connection bound to this device, if any
    OLD_CON=$(nmcli -t -f NAME,DEVICE con show | awk -F: -v dev="$INTERFACE" '$2==dev {print $1}')
    if [[ -n "$OLD_CON" ]]; then
        nmcli con delete "$OLD_CON"
    fi

    # Create or update connection named same as interface
    nmcli con add type ethernet ifname "$INTERFACE" con-name "$INTERFACE" \
        ipv4.method manual \
        ipv4.addresses "$IPADDR/$PREFIX" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS1 $DNS2" \
        autoconnect yes

    nmcli con up "$INTERFACE"

    echo "Changes applied! Verify with:"
    echo "ip addr show $INTERFACE"
    echo "ip route show"
fi

echo "Done! Backup file: $BACKUP_FILE"

fi

# Check Network.
echo "$(date +%Y%m%d-%T) - Check Network."
#read -p "Please input IP adress for eth0: " ipaddress
#read -p "Please input default gateway's IP for eth0: " defaultgateway
ping -c 3 $GATEWAY 

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
sed -i "1i $IPADDR $os_hostname" /etc/hosts

# Setup NTP cron job.
read -p "Please enter NTP server: " ntpserver
crontab -l | { cat; echo "* */1 * * * /usr/sbin/ntpdate $ntpserver"; } | crontab -

# Disable Selinux.
echo ""
echo "$(date +%Y%m%d-%T) - Disable Selinux." >> /tmp/WSG_pre-install_log_$(date +%F).log
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config
setenforce 0

# Pre-install needed services and packages.
dnf update list

echo ""
echo "$(date +%Y%m%d-%T) -  Pre-install and enable needed services and packages." >> /tmp/WSG_pre-install_log_$(date +%F).log
for need_services in wget unzip telnet ntp openssh-clients net-tools bind-utils sysstat lsof pciutils tcpdump lynx  ; do
	dnf install $need_services -y
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
	dnf install $WSE -y
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
	dnf install $WCG -y
	if [ $? -eq 0 ]; then
		echo "$(date +%Y%m%d-%T) - [$WCG] install seccussfully." >> /tmp/WSG_pre-install_log_$(date +%F).log
	else
		echo "$(date +%Y%m%d-%T) - [$WCG] install failed, please try again later." >> /tmp/WSG_pre-install_log_$(date +%F).log
	fi
done

# Enable / Disable needed services.
echo ""
echo "$(date +%Y%m%d-%T) - Enable / Disable needed services." >> /tmp/WSG_pre-install_log_$(date +%F).log
#systemctl stop NetworkManager
#systemctl disable NetworkManager
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
cat > wsgma.sh << 'EOF'
#!/bin/bash
rm -fr /tmp/wsgma/
mkdir /tmp/wsgma
hostname > /tmp/wsgma/wsgmaetc_hostname.txt
export > /tmp/wsgma/export.txt
env > /tmp/wsgma/env.txt
cat /etc/issue | head -1 > /tmp/wsgma/etc_issue.txt
uname -a > /tmp/wsgma/etc_uname.txt
ifconfig > /tmp/wsgma/etc_ifconfig.txt
cat /etc/sysconfig/network-scripts/ifcfg-* > /tmp/wsgma/ifcfg-config.txt
route > /tmp/wsgma/route.txt
iptables -L > /tmp/wsgma/iptables.txt
ip6tables -L > /tmp/wsgma/ip6tables.txt
chkconfig --list > /tmp/wsgma/chkconfiglist.txt
cat /etc/networks > /tmp/wsgma/etc_networks.txt
cat /etc/sysconfig/network > /tmp/wsgma/etc_sysconfig_network.txt
cat /etc/resolv.conf > /tmp/wsgma/etc_resolv.conf.txt
cat /etc/sysctl.conf > /tmp/wsgma/etc_sysctl.conf.txt
sysctl -a > /tmp/wsgma/sysctl.txt
systemctl --all > /tmp/wsgma/systemctl_all.txt
systemctl list-unit-files > /tmp/wsgma/systemctl_list-unit-files.txt
cat /etc/profile > /tmp/wsgma/etc_profile.txt
cat /etc/hosts > /tmp/wsgma/etc_hosts.txt
cat /etc/hosts.allow > /tmp/wsgma/etc_hosts.allow.txt
cat /etc/hosts.deny > /tmp/wsgma/etc_hosts.deny.txt
cat /etc/ssh/sshd_config > /tmp/wsgma/etc_ssh_sshd_config.txt
ps aux > /tmp/wsgma/psaux.txt
pstree -a -c -g -l -p -s -S -u > /tmp/wsgma/pstree.txt
top -b -n 1 > /tmp/wsgma/top.txt
cat /proc/cpuinfo > /tmp/wsgma/cpuinfo.txt
cat /proc/meminfo > /tmp/wsgma/meminfo.txt
free > /tmp/wsgma/free.txt
vmstat > /tmp/wsgma/vmstat.txt
iostat -d -k 1 10 > /tmp/wsgma/iostat.txt
netstat -anolp > /tmp/wsgma/netstat.txt
arp -a > /tmp/wsgma/arp.txt
lsof -i > /tmp/wsgma/lsof.txt
lsmod > /tmp/wsgma/lsmod.txt
lspci > /tmp/wsgma/lspci.txt
dmesg -T > /tmp/wsgma/dmesg.txt
fdisk -l > /tmp/wsgma/fdisk.txt
df -h > /tmp/wsgma/dfh.txt
cat /etc/fstab > /tmp/wsgma/etc_fstab.txt
rpm -qa | sort | uniq > /tmp/wsgma/rpmqa.txt
last > /tmp/wsgma/last.txt
crontab -l > /tmp/wsgma/cronjob_root.txt
cat /var/spool/mail/root > /tmp/wsgma/email_message_root.txt
cat /root/.bash_history > /tmp/wsgma/history_root.txt
cat /var/log/messages* | sort | uniq > /tmp/wsgma/varlog_messages_uniq.txt
cp /var/log/messages /tmp/wsgma/varlog_messages.today.txt
cat /var/log/dracut.log* | sort -M -r > /tmp/wsgma/dracut.log.txt
cat /var/log/anaconda.ifcfg.log > /tmp/wsgma/anaconda.ifcfg.log.txt
cat /var/log/anaconda.log > /tmp/wsgma/anaconda.log.txt
cat /var/log/anaconda.program.log > /tmp/wsgma/anaconda.program.log.txt
cat /var/log/anaconda.storage.log > /tmp/wsgma/anaconda.storage.log.txt
cat /var/log/anaconda.syslog > /tmp/wsgma/anaconda.syslog.txt
cat /var/log/anaconda.yum.log > /tmp/wsgma/anaconda.yum.log.txt
cat /var/log/boot.log > /tmp/wsgma/boot.log.txt
cat /var/log/cron.log > /tmp/wsgma/cron.txt
cat /var/log/secure > /tmp/wsgma/secure.txt
cat /var/log/yum.log* | sort -M -r > /tmp/wsgma/yum.log.txt
cat /var/log/anaconda.yum.log > /tmp/wsgma/anaconda.yum.log.txt
du -sh /opt/WCG/ > /tmp/wsgma/du_opt_wcg.txt
du -sh /opt/websense/ > /tmp/wsgma/du_opt_websense.txt
cat /opt/Websense/bin/WebsenseEIMServer.log > /tmp/wsgma/opt_Websense_bin_WebsenseEIMServer.log.txt
tail -10000 /opt/WCG/logs/content_gateway.out > /tmp/wsgma/wsg_content_gateway.out_top_10000.txt
tail -10000 /opt/WCG/logs/mgmtd_client.log > /tmp/wsgma/wsg_mgmtd_client.log_top_10000.txt
tail -10000 /opt/WCG/logs/PolicyEngineInterface.log > /tmp/wsgma/wsg_PolicyEngineInterface.log_top_10000.txt
tail -10000 /opt/WCG/logs/smbadmin.join.log > /tmp/wsgma/wsg_smbadmin.join.log_top_10000.txt
tail -100 /opt/WCG/logs/smbadmin.log > /tmp/wsgma/wsg_smbadmin.log_top_100.txt
tail -100 /opt/WCG/logs/smbadmin.techsupport.log > /tmp/wsgma/wsg_smbadmin.techsupport.log_top_100.txt
tail -100 /opt/WCG/logs/smbadmin.test.log > /tmp/wsgma/wsg_smbadmin.test.log_top_100.txt
tail -10000 /opt/WCG/logs/wcguicert.log > /tmp/wsgma/wsg_wcguicert.log_top_10000.txt
tail -100 /opt/WCG/logs/ant_server.ccastats.collated > /tmp/wsgma/wsg_ant_server.ccastats.collated_top_100.txt
tail -100 /opt/WCG/logs/ant_server.ccastats.sh > /tmp/wsgma/wsg_ant_server.ccastats.sh_top_100.txt
tail -100 /opt/WCG/logs/crl_log_update > /tmp/wsgma/wsg_crl_log_update_top_100.txt
tail -100 /opt/WCG/logs/ddscomm-trace.log > /tmp/wsgma/wsg_ddscomm-trace.log_top_100.txt
tail -100 /opt/WCG/logs/dss_registration.log > /tmp/wsgma/wsg_dss_registration.log_top_100.txt
tail -10000 /opt/WCG/logs/error.log > /tmp/wsgma/wsg_error.log_top_10000.txt
tail -10000 /opt/WCG/logs/extended.log > /tmp/wsgma/wsg_extended.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/CleanupAndArchive.log > /tmp/wsgma/pe_CleanupAndArchive.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/FPR.log > /tmp/wsgma/pe_FPR.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/HealthCheck.log > /tmp/wsgma/pe_HealthCheck.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/HmanagePolicyEngine.log > /tmp/wsgma/pe_managePolicyEngine.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/mgmtd.log > /tmp/wsgma/pe_mgmtd.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/PolicyEngine.log > /tmp/wsgma/pe_PolicyEngine.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/ResourceResolverImporter.log > /tmp/wsgma/pe_ResourceResolverImporter.log_top_10000.txt
tail -10000 /opt/websense/PolicyEngine/Logs/watchdog.log > /tmp/wsgma/pe_watchdog.log_top_10000.txt
sh /opt/WCG/bin/wcg_net_check.sh > /tmp/wsgma/wcg_net_check.txt
sh /opt/WCG/bin/wcg_show_config.sh > /tmp/wsgma/wcg_show_config.txt
sh /opt/WCG/bin/wcg_stats.sh > /tmp/wsgma/wcg_stats.txt
sh /opt/WCG/bin/netcontrol.sh -l > /tmp/wsgma/netcontrol.txt
cp /opt/Websense/bin/*.ini /tmp/wsgma/.
cp /opt/Websense/bin/*.xml /tmp/wsgma/.
cp /opt/Websense/bin/*.log /tmp/wsgma/.
cp /opt/Websense/bin/*.log.* /tmp/wsgma/.
cp /opt/websense/PolicyEngine/*.xml /tmp/wsgma/.
cp /opt/websense/PolicyEngine/Logs/*.* /tmp/wsgma/.
cp /root/WCG/Current/* /tmp/wsgma/.
cp /opt/websense/PolicyEngine/conf/* /tmp/wsgma/.
cp /opt/Websense/log_*.zip /tmp/wsgma/.
cp -r /opt/Websense/BlockPages/ /tmp/wsgma/.
cat /opt/WCG/logs/extended.log | perl /opt/WCG/bin/wcg_extended_stats.pl > /tmp/wsgma/wsg_extended_log_stats.txt
cat /opt/WCG/config/admin_access.config > /tmp/wsgma/opt_WCG_config_admin_access.config.txt
cat /opt/WCG/config/auth_domains.config > /tmp/wsgma/opt_WCG_config_auth_domains.config.txt
cat /opt/WCG/config/auth_rules.config > /tmp/wsgma/opt_WCG_config_auth_rules.config.txt
cat /opt/WCG/config/broker.config > /tmp/wsgma/opt_WCG_config_broker.config.txt
cat /opt/WCG/config/bypass.config > /tmp/wsgma/opt_WCG_config_bypass.config.txt
cat /opt/WCG/config/cache.config > /tmp/wsgma/opt_WCG_config_cache.config.txt
cat /opt/WCG/config/cluster.config > /tmp/wsgma/opt_WCG_config_cluster.config.txt
cat /opt/WCG/config/congestion.config > /tmp/wsgma/opt_WCG_config_congestion.config.txt
cat /opt/WCG/config/dns_prefer_exception.config > /tmp/wsgma/opt_WCG_config_dns_prefer_exception.config.txt
cat /opt/WCG/config/file_types.config > /tmp/wsgma/opt_WCG_config_file_types.config.txt
cat /opt/WCG/config/filter.config > /tmp/wsgma/opt_WCG_config_filter.config.txt
cat /opt/WCG/config/ftp_remap.config > /tmp/wsgma/opt_WCG_config_ftp_remap.config.txt
cat /opt/WCG/config/hosting.config > /tmp/wsgma/opt_WCG_config_hosting.config.txt
cat /opt/WCG/config/icp.config > /tmp/wsgma/opt_WCG_config_icp.config.txt
cat /opt/WCG/config/ip_allow.config > /tmp/wsgma/opt_WCG_config_ip_allow.config.txt
cat /opt/WCG/config/log_hosts.config > /tmp/wsgma/opt_WCG_config_log_hosts.config.txt
cat /opt/WCG/config/logs_xml.config > /tmp/wsgma/opt_WCG_config_logs_xml.config.txt
cat /opt/WCG/config/mgmt_allow.config > /tmp/wsgma/opt_WCG_config_mgmt_allow.config.txt
cat /opt/WCG/config/mimes.config > /tmp/wsgma/opt_WCG_config_mimes.config.txt
cat /opt/WCG/config/parent.config > /tmp/wsgma/opt_WCG_config_parent.config.txt
cat /opt/WCG/config/partition.config > /tmp/wsgma/opt_WCG_config_partition.config.txt
cat /opt/WCG/config/plugin.config > /tmp/wsgma/opt_WCG_config_plugin.config.txt
cat /opt/WCG/config/PolicyEngineInterface.log.config > /tmp/wsgma/opt_WCG_config_PolicyEngineInterface.log.config.txt
cat /opt/WCG/config/records.config > /tmp/wsgma/opt_WCG_config_records.config.txt
cat /opt/WCG/config/remap.config > /tmp/wsgma/opt_WCG_config_remap.config.txt
cat /opt/WCG/config/scan.config > /tmp/wsgma/opt_WCG_config_scan.config.txt
cat /opt/WCG/config/socks.config > /tmp/wsgma/opt_WCG_config_socks.config.txt
cat /opt/WCG/config/socks_server.config > /tmp/wsgma/opt_WCG_config_socks_server.config.txt
cat /opt/WCG/config/splitdns.config > /tmp/wsgma/opt_WCG_config_splitdns.config.txt
cat /opt/WCG/config/ssl_multicert.config > /tmp/wsgma/opt_WCG_config_ssl_multicert.config.txt
cat /opt/WCG/config/storage.config > /tmp/wsgma/opt_WCG_config_storage.config.txt
cat /opt/WCG/config/update.config > /tmp/wsgma/opt_WCG_config_update.config.txt
cat /opt/WCG/config/vaddrs.config > /tmp/wsgma/opt_WCG_config_vaddrs.config.txt
cat /opt/WCG/config/wccp.config > /tmp/wsgma/opt_WCG_config_wccp.config.txt
ls -lhaiRt -F --full-time /opt/ > /tmp/wsgma/all_files.txt
rm -fr /tmp/wsgma/mrtg
mkdir /tmp/wsgma/mrtg
cp /opt/WCG/ui/mrtg/*.png /tmp/wsgma/mrtg/.
timeout 60 tcpdump -vv -x -s 0 -i any ! port 22 -w /tmp/wsgma/wcg.pcap
rm -fr /tmp/`hostname`_`date "+%y%m%d"`.tar.gz
mv /tmp/wsgma /tmp/`hostname`_`date "+%y%m%d"`
export GZIP=-9
tar -zcvf /tmp/`hostname`_`date "+%y%m%d"`.tar.gz /tmp/`hostname`_`date "+%y%m%d"`
rm -fr /tmp/`hostname`_`date "+%y%m%d"`
#rm -fr /tmp/`hostname`_`date "+%y%m%d"`.zip
#zip -9 -r /tmp/`hostname`_`date "+%y%m%d"`.zip /tmp/wsgma/*
EOF
chmod a+x /root/wsgma.sh

echo "Please reboot your system."
exit 0
