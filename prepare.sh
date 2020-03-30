#!/bin/sh

sudo add-apt-repository ppa:wireguard/wireguard -y
sudo apt-get update
sudo apt-get install wireguard -y

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
