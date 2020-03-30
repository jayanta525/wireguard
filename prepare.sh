#!/bin/sh

sudo add-apt-repository ppa:wireguard/wireguard -y
sudo apt-get update
sudo apt-get install wireguard -y

sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved

echo "nameserver 8.8.8.8" > /etc/resolv.conf
