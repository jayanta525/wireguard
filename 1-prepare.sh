#!/bin/sh

sudo add-apt-repository ppa:wireguard/wireguard -y
sudo apt-get update
sudo apt-get install wireguard -y
sudo apt-get install qrencode -y

sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved

rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/wg.conf

sysctl --system

ufw allow ssh
ufw allow 53
echo "y" | ufw enable

mkdir wg0
cd wg0
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
echo "[Interface]" > wg0.conf
echo "PrivateKey = $(cat privatekey)" >> wg0.conf
echo "Address = 10.42.0.1/24" >> wg0.conf
echo "ListenPort = 53" >> wg0.conf
echo "PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" >> wg0.conf
echo "PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" >> wg0.conf

