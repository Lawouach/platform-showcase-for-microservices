#!/bin/bash
. /tmp/vars.sh

sudo rpm -i http://repos.mesosphere.io/el/7/noarch/RPMS/mesosphere-el-repo-7-3.noarch.rpm
sudo yum -y -q install mesos marathon mesosphere-zookeeper


# Zookeeper
export ZOOKEEPER_ID=1
echo $ZOOKEEPER_ID | sudo tee -a /var/lib/zookeeper/myid
echo "server.$ZOOKEEPER_ID=$MYIP:2888:3888" | sudo tee -a /etc/zookeeper/conf/zoo.cfg
sudo systemctl start zookeeper
sudo systemctl enable zookeeper


# Master
export MESOS_MASTER=$MYIP
echo zk://$MESOS_MASTER:2181/mesos | sudo tee /etc/mesos/zk
echo $MESOS_MASTER | sudo tee /etc/mesos-master/hostname
echo 1 | sudo tee /etc/mesos-master/quorum
echo "0.0.0.0" | sudo tee /etc/mesos-master/ip
echo $MYIP | sudo tee /etc/mesos-master/advertise_ip
sudo install -o root -g root -d /etc/marathon/conf
echo http_callback | sudo tee /etc/marathon/conf/event_subscriber

sudo systemctl daemon-reload

sudo systemctl stop mesos-slave
sudo systemctl disable mesos-slave

sudo systemctl restart mesos-master marathon
sudo systemctl enable mesos-master marathon

echo '{"service": {"name": "mesos", "tags": ["mesos"], "address": "'$MYIP'", "port": 5050, "check": {"script": "curl localhost:5050 >/dev/null 2>&1", "interval": "10s"}}}' | sudo tee /etc/consul.d/mesos.json
echo '{"service": {"name": "marathon", "tags": ["marathon"], "address": "'$MYIP'", "port": 8080, "check": {"script": "curl localhost:8080 >/dev/null 2>&1", "interval": "10s"}}}' | sudo tee /etc/consul.d/marathon.json
echo '{"service": {"name": "mesos-zookeeper", "tags": ["mesos-zookeeper"], "address": "'$MYIP'", "port": 2181}}' | sudo tee /etc/consul.d/mesos-zookeeper.json

sudo systemctl reload consul

# Marathon-lb
#docker pull mesosphere/marathon-lb
#sudo docker run -e PORTS=9090 --privileged --net=host mesosphere/marathon-lb sse --group '*' --marathon http://localhost:8080
