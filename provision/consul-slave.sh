#!/bin/bash
. /tmp/vars.sh

wget --quiet https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip
unzip consul_0.6.4_linux_amd64.zip

chmod a+x consul
sudo install -o root -g root consul /usr/local/bin/consul
sudo install -o root -g root -d /etc/consul.d
sudo install -o root -g root -d /var/lib/consul

cat <<EOF | sudo tee /etc/consul.d/config.json
{
    "bootstrap": false,
    "server": false,
    "datacenter": "dc1",
    "data_dir": "/var/lib/consul",
    "advertise_addr": "$MYIP",
    "client_addr": "0.0.0.0",
    "start_join": ["$MASTER_IP"]
}
EOF

cat <<EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/usr/local/bin/consul reload
ExecStop=/usr/local/bin/consul leave

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start consul
sudo systemctl enable consul
