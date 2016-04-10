#!/bin/bash
. /tmp/vars.sh

# first we need an etcd cluster
# let's make it a cluster of a single node
curl -L  https://github.com/coreos/etcd/releases/download/v2.3.1/etcd-v2.3.1-linux-amd64.tar.gz -o etcd-v2.3.1-linux-amd64.tar.gz
tar xzvf etcd-v2.3.1-linux-amd64.tar.gz
sudo install -o centos -g centos -d /usr/local/etcd
sudo install -o centos -g centos -d /var/lib/etcd
sudo cp -r etcd-v2.3.1-linux-amd64/* /usr/local/etcd

cat <<EOF | sudo tee /etc/sysconfig/etcd
ETCD_DATA_DIR=/var/lib/etcd
ETCD_NAME=%m
EOF

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd key-value store
Documentation=https://github.com/coreos/etcd
After=network-online.target

[Service]
User=centos
Type=notify
EnvironmentFile=-/etc/sysconfig/etcd
ExecStart=/usr/local/etcd/etcd
ExecStop=/bin/kill -TERM $MAINPID
RestartSec=10s
LimitNOFILE=40000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable etcd
sudo systemctl start etcd


# now we can run vulcand
wget https://github.com/vulcand/vulcand/releases/download/v0.8.0-beta.3/vulcand-v0.8.0-beta.3-linux-amd64.tar.gz
tar zxvf vulcand-v0.8.0-beta.3-linux-amd64.tar.gz
sudo install -o centos -g centos -d /usr/local/vulcand
sudo cp -r vulcand-v0.8.0-beta.3-linux-amd64/* /usr/local/vulcand

cat <<EOF | sudo tee /etc/sysconfig/vulcand
OPTIONS="-apiInterface=0.0.0.0 -etcd=http://127.0.0.1:4001"
EOF

cat <<EOF | sudo tee /etc/systemd/system/vulcand.service
[Unit]
Description=vulcand reverse proxy
Documentation=http://vulcand.github.io/
Requires=etcd.service
After=etcd.service

[Service]
EnvironmentFile=-/etc/sysconfig/vulcand
ExecStart=/usr/local/vulcand/vulcand $OPTIONS
ExecStop=/bin/kill -TERM $MAINPID
RestartSec=10s
LimitNOFILE=40000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable vulcand
sudo systemctl start vulcand

echo '{"service": {"name": "vulcand", "tags": ["vulcand"], "address": "'$MYIP'", "port": 8182}}' | sudo tee /etc/consul.d/vulcand.json
sudo systemctl reload consul
