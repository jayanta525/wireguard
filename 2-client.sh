#!/bin/sh

echo "Enter the client name: "
read client
mkdir $client
cd $client
wg genkey | tee privatekey | wg pubkey > publickey
echo "[Interface]" > wg0.conf
echo "PrivateKey = $(cat privatekey)" >> wg0.conf
echo "Address = 10.42.0.2/24" >> wg0.conf
echo "DNS = 8.8.8.8,1.1.1.1" >> wg0.conf

vpsip=$(curl http://ipv4.openmptcprouter.com/)
echo "$vpsip"

echo "[Peer]" >> wg0.conf
echo "PublicKey = $(cat ../publickey)" >> wg0.conf
echo "Endpoint = $vpsip:53" >> wg0.conf
echo "AllowedIPs = 0.0.0.0/0" >> wg0.conf

echo "[Peer]" >> ../wg0.conf
echo "PublicKey = $(cat publickey)" >> ../wg0.conf
echo "AllowedIPs = 10.42.0.2/32" >> ../wg0.conf

cd ..
qrencode -t ansiutf8 < $client/wg0.conf
