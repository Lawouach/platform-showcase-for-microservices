#!/bin/bash
. /tmp/vars.sh

curl -sSL https://get.docker.com/ | sudo sh
sudo usermod -aG docker centos

sudo sed -i 's|ExecStart=/usr/bin/docker daemon -H fd://|EnvironmentFile=-/etc/sysconfig/docker\nExecStart=/usr/bin/docker daemon -H fd:// -H unix:///var/run/docker.sock \$OPTIONS|' /usr/lib/systemd/system/docker.service

echo OPTIONS=\"--dns $MYIP --dns-search service.consul\" | sudo tee -a /etc/sysconfig/docker
sudo systemctl enable docker
sudo systemctl start docker

###################################################
# Weave install
###################################################
curl -L git.io/weave -o weave
sudo install -o root -g root -m 0755 weave /usr/local/bin/

cat <<EOF | sudo tee /usr/lib/systemd/system/weave.service
[Unit]
Description=Weave Network
Documentation=http://docs.weave.works/weave/latest_release/
Requires=docker.service
After=docker.service

[Service]
TimeoutStartSec=0
EnvironmentFile=-/etc/sysconfig/weave
ExecStartPre=/usr/local/bin/weave launch --no-dns \$PEERS
ExecStartPre=/usr/local/bin/weave launch-proxy --without-dns
ExecStartPre=/usr/local/bin/weave launch-plugin
ExecStart=/usr/bin/docker attach weave
ExecStop=/usr/local/bin/weave stop
Restart=on-failure

[Install]
WantedBy=weave.target
EOF

cat <<EOF | sudo tee /usr/lib/systemd/system/weave.target
[Unit]
Description=Weave
Documentation=man:systemd.special(7)
RefuseManualStart=no
After=network-online.target
Requires=weave.service
[Install]
WantedBy=multi-user.target
EOF
sudo chmod 644 /usr/lib/systemd/system/weave.target /usr/lib/systemd/system/weave.service
sudo systemctl enable weave.service

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl start --no-block weave
