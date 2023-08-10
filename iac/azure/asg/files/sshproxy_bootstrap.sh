#!/bin/bash -xe

# Enable ip forwarding and nat
#sysctl -w net.ipv4.ip_forward=1

# Make forwarding persistent.
#sed -i= 's/^[# ]*net.ipv4.ip_forward=[[:digit:]]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

apt-get update

# install monitoring utils
apt-get install -y htop bmon iotop dstat