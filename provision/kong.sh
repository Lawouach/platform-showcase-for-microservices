#!/bin/bash
. /tmp/vars.sh

sudo yum install -y epel-release

# First we need cassandra
sudo yum install -y -q java-1.8.0-openjdk-devel
cat <<EOF  | sudo tee /etc/yum.repos.d/datastax.repo
[datastax] 
name = DataStax Repo for Apache Cassandra
baseurl = http://rpm.datastax.com/community
enabled = 1
gpgcheck = 0
EOF
sudo yum -y -q install dsc22 cassandra2
# datastax still uses the old service interface
sudo service cassandra start
sudo systemctl enable cassandra


# Now we can install kong
#sudo yum install -y epel-release
wget -q -O kong-0.7.0.el7.noarch.rpm https://downloadkong.org/el7.noarch.rpm
sudo yum install -y -q kong-0.7.0.el7.noarch.rpm --nogpgcheck

# to get it working properly with systemd, we can't
# let nginx start in the background
sudo sed -i "s/daemon on/daemon off/" /etc/kong/kong.yml

#cat <<EOF | sudo tee -a /etc/kong/kong.yml
#dns_resolver: server
#dns_resolvers_available:
#  server:
#    address: "$CONSUL_MASTER:8600"
#EOF

cat <<EOF | sudo tee /usr/lib/systemd/system/kong.service
[Unit]
Description=Kong Proxy
Documentation=https://getkong.org/
Requires=network-online.target
After=network-online.target

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/kong start
ExecStop=/usr/local/bin/kong stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo install -o root -g root -d /etc/systemd/system/kong.service.d
cat <<EOF | sudo tee /etc/systemd/system/kong.service.d/limits.conf
[Service]
LimitNOFILE=4096
EOF

sudo systemctl daemon-reload
sudo systemctl start kong
sudo systemctl enable kong

# let's register kong so other services can locate it
echo '{"ID": "kong", "Name": "kong", "Tags": ["kong"], "Address": "'$MYIP'", "Port": 8001}}' > kong.json
curl -X POST http://$CONSUL_MASTER:8500/v1/agent/service/register -d @kong.json -H "Content-type: application/json"
