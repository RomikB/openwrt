#!/bin/sh
#
# Wi-Fi AP Start Script for Xiaomi Router BE3600 (RD15)
# Creates VAP interfaces (ath0 for 2.4G, ath1 for 5G), bridges to br-lan, and starts hostapd (Wi-Fi 6)
#

echo "=================================================="
echo "    Starting Wi-Fi 6 Access Points (2.4G / 5G)   "
echo "=================================================="

# 1. Ensure driver is loaded
[ -d /sys/module/wifi_3_0 ] || {
	echo "Wi-Fi driver not loaded, starting /etc/init.d/qca-wifi..."
	/etc/init.d/qca-wifi start
	sleep 2
}

# 2. Ensure br-lan is UP
[ -d /sys/class/net/br-lan ] || brctl addbr br-lan 2>/dev/null || true
ip link set br-lan up 2>/dev/null || true

# 3. Disable bridge netfilter packet dropping
sysctl -w net.bridge.bridge-nf-call-iptables=0 2>/dev/null || true
sysctl -w net.bridge.bridge-nf-call-arptables=0 2>/dev/null || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=0 2>/dev/null || true

# 4. Get phy names
PHY0=$(cat /sys/class/net/wifi0/phy80211/name 2>/dev/null || echo "phy1")
PHY1=$(cat /sys/class/net/wifi1/phy80211/name 2>/dev/null || echo "phy2")

# 5. Create fresh VAPs
if [ ! -d /sys/class/net/ath0 ]; then
	echo "Creating VAP ath0 on $PHY0..."
	iw phy "$PHY0" interface add ath0 type __ap 2>&1 || true
fi

if [ ! -d /sys/class/net/ath1 ]; then
	echo "Creating VAP ath1 on $PHY1..."
	iw phy "$PHY1" interface add ath1 type __ap 2>&1 || true
fi

# 6. Attach VAPs to br-lan and bring UP
echo "Attaching ath0 and ath1 to br-lan..."
brctl addif br-lan ath0 2>/dev/null || true
brctl addif br-lan ath1 2>/dev/null || true
ip link set ath0 up 2>/dev/null || true
ip link set ath1 up 2>/dev/null || true

# 7. Configure NAT and firewall forwarding
iptables -I FORWARD -i br-lan -j ACCEPT 2>/dev/null || true
iptables -I FORWARD -o br-lan -j ACCEPT 2>/dev/null || true
iptables -t nat -I POSTROUTING -s 192.168.1.0/24 -j MASQUERADE 2>/dev/null || true

# 8. Generate hostapd configurations (Wi-Fi 6 AX)
mkdir -p /var/run/hostapd

cat << 'EOF' > /var/run/hostapd-ath0.conf
driver=nl80211
interface=ath0
bridge=br-lan
ssid=OpenWrt_RD15_2.4G
hw_mode=g
channel=1
ieee80211n=1
ieee80211ax=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=12345678
ctrl_interface=/var/run/hostapd
EOF

cat << 'EOF' > /var/run/hostapd-ath1.conf
driver=nl80211
interface=ath1
bridge=br-lan
ssid=OpenWrt_RD15_5G
hw_mode=a
channel=36
ieee80211n=1
ieee80211ac=1
ieee80211ax=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=12345678
ctrl_interface=/var/run/hostapd
EOF

# 9. Stop existing hostapd instances
killall hostapd 2>/dev/null || true
sleep 1

# 10. Start hostapd (separate processes for 2.4G and 5G)
echo "Starting hostapd daemon on ath0 and ath1..."
/usr/sbin/hostapd -B -P /var/run/hostapd-ath0.pid -e /var/run/entropy.bin /var/run/hostapd-ath0.conf
/usr/sbin/hostapd -B -P /var/run/hostapd-ath1.pid -e /var/run/entropy.bin /var/run/hostapd-ath1.conf
sleep 1

# 11. Check status
echo ""
echo "--- Hostapd Process Status ---"
ps | grep hostapd | grep -v grep

echo ""
echo "--- Bridge Status ---"
brctl show

echo ""
echo "=== Wi-Fi 6 Access Points Started ==="
echo "2.4 GHz SSID: OpenWrt_RD15_2.4G (Wi-Fi 6, Password: 12345678)"
echo "5.0 GHz SSID: OpenWrt_RD15_5G   (Wi-Fi 6, Password: 12345678)"
