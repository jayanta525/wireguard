echo "Enter Client Name: "
read CLIENT

CLIENT_ID=$(cat client.ipv4)
TEMP=$((CLIENT_ID++))

SERVER_PUB_KEY=$(cat server.pub)

SERVER_PUB_IPV4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
read -rp "IPv4 or IPv6 public address: " -e -i "$SERVER_PUB_IPV4" SERVER_PUB_IP

SERVER_WG_NIC="wg0"
read -rp "WireGuard interface name: " -e -i "$SERVER_WG_NIC" SERVER_WG_NIC

SERVER_PORT=53
read -rp "Server's WireGuard port " -e -i "$SERVER_PORT" SERVER_PORT

CLIENT_WG_IPV4="10.66.66.$CLIENT_ID"
read -rp "Client's WireGuard IPv4 " -e -i "$CLIENT_WG_IPV4" CLIENT_WG_IPV4

CLIENT_WG_IPV6="fd42:42:42::$CLIENT_ID"
read -rp "Client's WireGuard IPv6 " -e -i "$CLIENT_WG_IPV6" CLIENT_WG_IPV6

# Adguard DNS by default
CLIENT_DNS_1="176.103.130.130"
read -rp "First DNS resolver to use for the client: " -e -i "$CLIENT_DNS_1" CLIENT_DNS_1

CLIENT_DNS_2="176.103.130.131"
read -rp "Second DNS resolver to use for the client: " -e -i "$CLIENT_DNS_2" CLIENT_DNS_2

if [[ $SERVER_PUB_IP =~ .*:.* ]]
then
  echo "IPv6 Detected"
  ENDPOINT="[$SERVER_PUB_IP]:$SERVER_PORT"
else
  echo "IPv4 Detected"
  ENDPOINT="$SERVER_PUB_IP:$SERVER_PORT"
fi

#Turn down interface

wg-quick down $SERVER_WG_NIC

CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

echo "[Peer]
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = $CLIENT_WG_IPV4/32,$CLIENT_WG_IPV6/128" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

# Create client file with interface
echo "[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_WG_IPV4/24,$CLIENT_WG_IPV6/64
DNS = $CLIENT_DNS_1,$CLIENT_DNS_2" > "$HOME/$SERVER_WG_NIC-client-$CLIENT.conf"

# Add the server as a peer to the client
echo "[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0,::/0" >> "$HOME/$SERVER_WG_NIC-client-$CLIENT.conf"

wg-quick up $SERVER_WG_NIC

echo -e "\nHere is your client config file as a QR Code:"

qrencode -t ansiutf8 -l L < "$HOME/$SERVER_WG_NIC-client-$CLIENT.conf"
