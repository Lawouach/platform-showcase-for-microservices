#!/bin/bash
. /tmp/vars.sh

sudo rpm -i http://repos.mesosphere.io/el/7/noarch/RPMS/mesosphere-el-repo-7-3.noarch.rpm
sudo yum -y -q install mesos marathon

sudo systemctl stop mesos-master marathon
sudo systemctl disable mesos-master marathon

# Slave
echo '10mins' | sudo tee /etc/mesos-slave/executor_registration_timeout
cat <<EOF > mesos-slave-containerizers.conf
[Service]
Environment=MESOS_CONTAINERIZERS=docker,mesos
Environment=MESOS_DOCKER_SOCKET=/var/run/weave/weave.sock
EOF
# let's use a greater port range for microservices
echo 'ports(*):[50000, 60000]' | sudo tee /etc/mesos-slave/resources
echo $MYIP | sudo tee /etc/mesos-slave/hostname
echo zk://$MASTER_IP:2181/mesos | sudo tee /etc/mesos/zk
echo "0.0.0.0" | sudo tee /etc/mesos-slave/ip
echo $MYIP | sudo tee /etc/mesos-slave/advertise_ip

sudo install -o root -g root -d /etc/systemd/system/mesos-slave.service.d
sudo install -o root -g root mesos-slave-containerizers.conf /etc/systemd/system/mesos-slave.service.d

sudo install -o root -g root -d /etc/marathon/conf
echo $MYIP | sudo tee /etc/marathon/conf/hostname

sudo systemctl daemon-reload
sudo systemctl restart mesos-slave
sudo systemctl enable mesos-slave
