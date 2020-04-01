#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

sudo add-apt-repository ppa:wireguard/wireguard -y
sudo apt-get update
sudo apt-get install wireguard -y
sudo apt-get install qrencode -y

sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

ufw allow ssh
ufw allow 53
echo "y" | ufw enable

#echo "[Interface]" > wg0.conf
#echo "Address = 10.66.66.1/24,fd42:42:42::1/64" >> wg0.conf
#echo "ListenPort = 1194" >> wg0.conf

###############################################################################
SERVER_PUB_IPV4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
read -rp "IPv4 or IPv6 public address: " -e -i "$SERVER_PUB_IPV4" SERVER_PUB_IP

# Detect public interface and pre-fill for the user
SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
read -rp "Public interface: " -e -i "$SERVER_PUB_NIC" SERVER_PUB_NIC

SERVER_WG_NIC="wg0"
read -rp "WireGuard interface name: " -e -i "$SERVER_WG_NIC" SERVER_WG_NIC

SERVER_WG_IPV4="10.66.66.1"
read -rp "Server's WireGuard IPv4 " -e -i "$SERVER_WG_IPV4" SERVER_WG_IPV4

SERVER_WG_IPV6="fd42:42:42::1"
read -rp "Server's WireGuard IPv6 " -e -i "$SERVER_WG_IPV6" SERVER_WG_IPV6

SERVER_PORT=53
read -rp "Server's WireGuard port " -e -i "$SERVER_PORT" SERVER_PORT

CLIENT_ID=2
echo "$CLIENT_ID" > client.ipv4

CLIENT_WG_IPV4="10.66.66.$CLIENT_ID"
read -rp "Client's WireGuard IPv4 " -e -i "$CLIENT_WG_IPV4" CLIENT_WG_IPV4



CLIENT_WG_IPV6="fd42:42:42::$CLIENT_ID"
read -rp "Client's WireGuard IPv6 " -e -i "$CLIENT_WG_IPV6" CLIENT_WG_IPV6


# Adguard DNS by default
CLIENT_DNS_1="176.103.130.130"
read -rp "First DNS resolver to use for the client: " -e -i "$CLIENT_DNS_1" CLIENT_DNS_1

CLIENT_DNS_2="176.103.130.131"
read -rp "Second DNS resolver to use for the client: " -e -i "$CLIENT_DNS_2" CLIENT_DNS_2
########################################

if [[ $SERVER_PUB_IP =~ .*:.* ]]
then
  echo "IPv6 Detected"
  ENDPOINT="[$SERVER_PUB_IP]:$SERVER_PORT"
else
  echo "IPv4 Detected"
  ENDPOINT="$SERVER_PUB_IP:$SERVER_PORT"
fi

SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

echo "$SERVER_PUB_KEY" > server.pub

# Generate key pair for the server
CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

echo "[Interface]
Address = $SERVER_WG_IPV4/24,$SERVER_WG_IPV6/64
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV_KEY" > "/etc/wireguard/$SERVER_WG_NIC.conf"

echo "PostUp = iptables -A FORWARD -o $SERVER_WG_NIC -j ACCEPT; iptables -A FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -A FORWARD -i $SERVER_WG_NIC -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
PostDown = iptables -D FORWARD -o $SERVER_WG_NIC -j ACCEPT; iptables -D FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -D FORWARD -i $SERVER_WG_NIC -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

echo "[Peer]
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = $CLIENT_WG_IPV4/32,$CLIENT_WG_IPV6/128" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

# Create client file with interface
echo "[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_WG_IPV4/24,$CLIENT_WG_IPV6/64
DNS = $CLIENT_DNS_1,$CLIENT_DNS_2" > "$HOME/$SERVER_WG_NIC-client.conf"

# Add the server as a peer to the client
echo "[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0,::/0" >> "$HOME/$SERVER_WG_NIC-client.conf"

echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/wg.conf

sysctl --system

systemctl start "wg-quick@$SERVER_WG_NIC"
systemctl enable "wg-quick@$SERVER_WG_NIC"

echo -e "\nHere is your client config file as a QR Code:"

qrencode -t ansiutf8 -l L < "$HOME/$SERVER_WG_NIC-client.conf"

systemctl is-active --quiet "wg-quick@$SERVER_WG_NIC"
WG_RUNNING=$?

