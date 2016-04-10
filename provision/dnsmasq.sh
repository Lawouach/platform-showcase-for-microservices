#!/bin/bash
. /tmp/vars.sh

# ensure we always go through dnsmasq first so that
# we can resolv through the consul DNS too

echo server=/consul/${CONSUL_MASTER:-127.0.0.1}#8600 | sudo tee /etc/dnsmasq.d/10-consul

# this next line will live only until the next reboot
sudo sed -i '2a nameserver 127.0.0.1' /etc/resolv.conf

# this will ensure following reboots will fill the resolve.conf
# appropriately
echo "prepend domain-name-servers 127.0.0.1;" | sudo tee -a /etc/dhcp/dhclient.conf

sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq
