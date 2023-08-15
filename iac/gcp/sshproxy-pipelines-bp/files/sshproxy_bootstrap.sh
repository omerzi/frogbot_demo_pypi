#!/bin/bash -xe

# Enable ip forwarding and nat
sysctl -w net.ipv4.ip_forward=1

# Make forwarding persistent.
sed -i= 's/^[# ]*net.ipv4.ip_forward=[[:digit:]]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE

apt-get update

# install monitoring utils
apt-get install -y htop bmon iotop dstat unzip

#remove sshguard
sudo apt-get purge -y --auto-remove sshguard

# install SDM
curl -J -O -L https://app.strongdm.com/releases/cli/linux && unzip sdmcli* && rm -f sdmcli*
sudo ./sdm install --relay --token="${gateway_token}"
