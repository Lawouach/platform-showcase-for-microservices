#!/bin/bash
. /tmp/vars.sh

sudo systemctl stop firewalld
sudo yum update -y
sudo yum install -y -q nano wget bridge-utils unzip curl ntp

sudo systemctl start ntpd
sudo systemctl enable ntpd

# let's make sure we preserve the hostname we are setting
NODE_NAME=`hostname -s`
echo "HOSTNAME=$HOSTNAME" | sudo tee -a /etc/sysconfig/network
sudo sed -i "s/localhost localhost.localdomain/$HOSTNAME $NODE_NAME localhost localhost.localdomain/" /etc/hosts
echo "preserve_hostname: true" | sudo tee -a /etc/cloud/cloud.cfg.d/99_hostname.cfg

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
