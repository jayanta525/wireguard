#!/bin/sh

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

mkdir wg0
cd wg0
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
privk=$(cat privatekey)
echo "[Interface]" > wg0.conf
echo "PrivateKey = $(cat privatekey)" >> wg0.conf
echo "Address = 10.42.0.1/24" >> wg0.conf
echo "ListenPort = 53" >> wg0.conf
