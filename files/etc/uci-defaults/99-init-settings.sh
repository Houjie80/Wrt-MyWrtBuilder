#!/bin/sh

exec > /root/setup.log 2>&1

# Set hostname and Timezone to Asia/Jakarta
uci set system.@system[0].timezone='WIB-7'
uci set system.@system[0].zonename='Asia/Jakarta'
uci delete system.ntp.server
uci add_list system.ntp.server="pool.ntp.org"
uci add_list system.ntp.server="id.pool.ntp.org"
uci add_list system.ntp.server="time.google.com"
uci commit system

#configure wan interface
uci set network.wan=interface 
uci set network.wan.proto='modemmanager'
uci set network.wan.device='/sys/devices/platform/scb/fd500000.pcie/pci0000:00/0000:00:00.0/0000:01:00.0/usb2/2-1'
uci set network.wan.apn='internet'
uci set network.wan.auth='none'
uci set network.wan.iptype='ipv4'
uci set network.lan.ipaddr="192.168.1.1"
uci commit network
/etc/init.d/network restart

uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci delete dhcp.lan.ndp
uci commit dhcp
/etc/init.d/dnsmasq restart

uci set firewall.@zone[1].network='wan'
uci commit firewall

#configure WLAN
uci set wireless.@wifi-iface[0].mode='ap'
uci set wireless.@wifi-device[0].disabled='0'
uci set wireless.@wifi-device[0].country='ID'
uci set wireless.@wifi-device[0].htmode='VHT40'
uci set wireless.@wifi-device[0].channel='161'
uci commit wireless

# remove huawei me909s usb-modeswitch
sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json

# remove dw5821e usb-modeswitch
sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json

# Disable /etc/config/xmm-modem
uci set xmm-modem.@xmm-modem[0].enable='0'
uci commit

# custom repo and Disable opkg signature check
if grep -qE '^VERSION_ID="23' /etc/os-release; then
   sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
   echo "src/gz custom_generic https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/main/generic" >> /etc/opkg/customfeeds.conf
   echo "src/gz custom_arch https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/main/$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')" >> /etc/opkg/customfeeds.conf
elif grep -qE '^VERSION_ID="21' /etc/os-release; then
   sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
   echo "src/gz custom_generic https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/generic" >> /etc/opkg/customfeeds.conf
   echo "src/gz custom_arch https://raw.githubusercontent.com/lrdrdn/my-opkg-repo/21.02/$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')" >> /etc/opkg/customfeeds.conf
fi

# add cron job for modem rakitan
echo '#auto renew ip lease for modem rakitan' >> /etc/crontabs/root
echo '30 3 * * 1,2,3,4,5,6 echo  AT+CFUN=4 | atinout - /dev/ttyUSB0 - && sleep 3 && ifdown wan && sleep 3 && echo  AT+CFUN=1 | atinout - /dev/ttyUSB0 - && sleep 3 && ifup wan' >> /etc/crontabs/root
echo '#auto restart for modem rakitan once a week'  >> /etc/crontabs/root
echo '30 3 * * 0 echo  AT^RESET | atinout - /dev/ttyUSB0 - && sleep 20 && ifdown wan && ifup wan'  >> /etc/crontabs/root

# Remove watchcat default config
uci delete watchcat.@watchcat[0]
uci commit

#setting firewall samba4
uci -q delete firewall.samba_nsds_nt
uci set firewall.samba_nsds_nt="rule"
uci set firewall.samba_nsds_nt.name="NoTrack-Samba/NS/DS"
uci set firewall.samba_nsds_nt.src="lan"
uci set firewall.samba_nsds_nt.dest="lan"
uci set firewall.samba_nsds_nt.dest_port="137-138"
uci set firewall.samba_nsds_nt.proto="udp"
uci set firewall.samba_nsds_nt.target="NOTRACK"
uci -q delete firewall.samba_ss_nt
uci set firewall.samba_ss_nt="rule"
uci set firewall.samba_ss_nt.name="NoTrack-Samba/SS"
uci set firewall.samba_ss_nt.src="lan"
uci set firewall.samba_ss_nt.dest="lan"
uci set firewall.samba_ss_nt.dest_port="139"
uci set firewall.samba_ss_nt.proto="tcp"
uci set firewall.samba_ss_nt.target="NOTRACK"
uci -q delete firewall.samba_smb_nt
uci set firewall.samba_smb_nt="rule"
uci set firewall.samba_smb_nt.name="NoTrack-Samba/SMB"
uci set firewall.samba_smb_nt.src="lan"
uci set firewall.samba_smb_nt.dest="lan"
uci set firewall.samba_smb_nt.dest_port="445"
uci set firewall.samba_smb_nt.proto="tcp"
uci set firewall.samba_smb_nt.target="NOTRACK"
uci commit firewall

uci set ttyd.@ttyd[0].command='/bin/bash --login'
uci commit

sed -i 's/services/nas/g' /usr/lib/lua/luci/controller/aria2.lua || sed -i 's/services/nas/g' /usr/share/luci/menu.d/luci-app-aria2.json
sed -i 's/services/nas/g' /usr/share/luci/menu.d/luci-app-samba4.json
sed -i 's/services/nas/g' /usr/share/luci/menu.d/luci-app-hd-idle.json
sed -i 's/services/nas/g' /usr/share/luci/menu.d/luci-app-disks-info.json
sed -i 's/services/status/g' /usr/share/luci/menu.d/luci-app-log.json

sed -i '/exit 0/i /usr/bin/patchoc.sh' /etc/rc.local
sed -i 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' /etc/profile
sed -i 's/\[ -n "$FAILSAFE" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/neofetch/' /etc/profile

echo '*/15 * * * * /sbin/free.sh' >> /etc/crontabs/root
echo '0 12 * * * /sbin/sync_time.sh beacon.liveon.id' >> /etc/crontabs/root
/etc/init.d/cron restart

mv /usr/share/openclash/ui/yacd /usr/share/openclash/ui/yacd.old && mv /usr/share/openclash/ui/yacd.new /usr/share/openclash/ui/yacd
bash /usr/bin/patchoc.sh

echo -e "\ndtparam=i2c1=on\ndtparam=spi=on\ndtparam=i2s=on" >> /boot/config.txt

# dont remove!
if grep -q "ImmortalWrt" /etc/openwrt_release; then
    sed -i "s/\(DISTRIB_DESCRIPTION='ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
    echo "ImmortalWrt version updated."
elif grep -q "OpenWrt" /etc/openwrt_release; then
    sed -i "s/\(DISTRIB_DESCRIPTION='OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
    echo "OpenWrt version updated."
else
    echo "No matching distribution found in /etc/openwrt_release."
fi

uci set nlbwmon.@nlbwmon[0].database_directory='/etc/nlbwmon'
uci set nlbwmon.@nlbwmon[0].commit_interval='3h'
uci set nlbwmon.@nlbwmon[0].refresh_interval='60s'
uci commit nlbwmon

sed -i 's/DatabaseDir "\/var\/lib\/vnstat"/DatabaseDir "\/etc\/vnstat"/g' /etc/vnstat.conf

reboot

exit 0