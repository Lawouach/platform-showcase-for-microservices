# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.credentials_profile}"
}

resource "aws_key_pair" "showcase" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}


# Create a VPC to launch our instances into
resource "aws_vpc" "mesos_marathon_demo" {
  cidr_block = "10.0.0.0/16"
}



resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.mesos_marathon_demo.id}"
    
    tags { 
    	 Name = "public-subnet-gw" 
    }	     
}



resource "aws_route_table" "private-subnet" {
    vpc_id = "${aws_vpc.mesos_marathon_demo.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.default.id}"
    }
    
    tags { 
    	 Name = "private-subnet-route" 
    }	      
}

resource "aws_route_table_association" "private-subnet" {
    subnet_id = "${aws_subnet.private-subnet.id}"
    route_table_id = "${aws_route_table.private-subnet.id}"
}



resource "aws_route_table" "public-subnet" {
    vpc_id = "${aws_vpc.mesos_marathon_demo.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.default.id}"
    }
    
    tags { 
    	 Name = "public-subnet-route" 
    }	
}

resource "aws_route_table_association" "public-subnet" {
    subnet_id = "${aws_subnet.public-subnet.id}"
    route_table_id = "${aws_route_table.public-subnet.id}"
}




resource "aws_subnet" "private-subnet" {
  vpc_id                  = "${aws_vpc.mesos_marathon_demo.id}"
  cidr_block              = "${var.private_subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone 	  = "${var.aws_availability_zone}"
  tags { 
    Name = "private-subnet" 
  }
}



# Create a public subnet to launch our proxy into
resource "aws_subnet" "public-subnet" {
  vpc_id                  = "${aws_vpc.mesos_marathon_demo.id}"
  cidr_block              = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone 	  = "${var.aws_availability_zone}"
  tags { 
    Name = "public-subnet" 
  }
}


resource "aws_security_group" "kong_sg" {
  name        = "kong_sg"
  description = "Kong security group"
  vpc_id      = "${aws_vpc.mesos_marathon_demo.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # our public traffic
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # kong api endpoint only available
  # from the internal network
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${aws_instance.master.private_ip}/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "master_sg" {
  name        = "master_sg"
  description = "Mesos/Marathon master security group"
  vpc_id      = "${aws_vpc.mesos_marathon_demo.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mesos/marathon zookeeper
  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # mesos 
  ingress {
    from_port   = 5050
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # marathon 
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # vulcand 
  ingress {
    from_port   = 8182
    to_port     = 8182
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # consul HTTP
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # consul DNS
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # consul DNS
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # consul RPC (CLI)
  ingress {
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # consul RPC 
  ingress {
    from_port = 8300
    to_port   = 8300
    protocol  = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }
    
  # consul LAN
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }
    
  # consul LAN
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # weave peers connections
  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # weave router connections (for fastdp)
  ingress {
    from_port   = 6784
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }
  
  # allowing service ports access from the
  # gateway
  ingress {
    from_port   = 10000
    to_port     = 11000
    protocol    = "tcp"
    cidr_blocks = ["${var.public_subnet_cidr}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "slave_sg" {
  name        = "slave_sg"
  description = "Mesos/Marathon slaves security group"
  vpc_id      = "${aws_vpc.mesos_marathon_demo.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # weave peers connections
  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # weave router connections (for fastdp)
  ingress {
    from_port   = 6784
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }
  
  # consul HTTP
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # consul LAN
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }
    
  # consul LAN
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # mesos 
  ingress {
    from_port   = 5051
    to_port     = 5051
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}", "${var.public_subnet_cidr}"]
  }

  # microservices (matching marathon's config)
  # defined in provision/mesos-slave.sh
  ingress {
    from_port   = 50000
    to_port     = 60000
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_eip" "kong" {
    instance = "${aws_instance.kong.id}"
    vpc = true
}


resource "aws_instance" "kong" {
  connection {
    user = "centos"
  }

  tags {
        Name = "kong"
  }

  instance_type = "${var.aws_slave_instance_size}"
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  key_name = "${aws_key_pair.showcase.id}"
  vpc_security_group_ids = ["${aws_security_group.kong_sg.id}"]
  subnet_id = "${aws_subnet.public-subnet.id}"
  depends_on = ["aws_instance.master"]
  root_block_device {
     delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname kong.${var.domain}",
      "echo MYIP=${self.private_ip} | sudo tee /tmp/vars.sh",
      "echo CONSUL_MASTER=${aws_instance.master.private_ip} | sudo tee -a /tmp/vars.sh"
    ]
  }
  
  provisioner "file" {
    source = "provision/sys.sh"
    destination = "/tmp/sys.sh"
  }
  
  provisioner "file" {
    source = "provision/kong.sh"
    destination = "/tmp/kong.sh"
  }
  
  provisioner "file" {
    source = "provision/dnsmasq.sh"
    destination = "/tmp/dnsmasq.sh"
  }
  
  provisioner "file" {
    source = "services/register-mesos-marathon-services.sh"
    destination = "/tmp/register-mesos-marathon-services.sh"
  }
  
  provisioner "file" {
    source = "services/register-service.sh"
    destination = "/home/centos/register-service.sh"
  }
  
  provisioner "file" {
    source = "services/deregister-service.sh"
    destination = "/home/centos/deregister-service.sh"
  }
  
  provisioner "file" {
    source = "services/register-instance.sh"
    destination = "/home/centos/register-instance.sh"
  }
  
  provisioner "file" {
    source = "services/deregister-instance.sh"
    destination = "/home/centos/deregister-instance.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sh /tmp/sys.sh",
      "sh /tmp/dnsmasq.sh",
      "sh /tmp/kong.sh"
    ]
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /home/centos/register-service.sh",
      "chmod a+x /home/centos/deregister-service.sh",
      "chown centos.centos /home/centos/register-service.sh",
      "chown centos.centos /home/centos/deregister-service.sh",
      "chmod a+x /home/centos/register-instance.sh",
      "chmod a+x /home/centos/deregister-instance.sh",
      "chown centos.centos /home/centos/register-instance.sh",
      "chown centos.centos /home/centos/deregister-instance.sh"
    ]
  }
}


resource "aws_instance" "master" {
  connection {
    user = "centos"
  }

  tags {
        Name = "master"
  }

  instance_type = "${var.aws_slave_instance_size}"
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  key_name = "${aws_key_pair.showcase.id}"
  vpc_security_group_ids = ["${aws_security_group.master_sg.id}"]
  subnet_id = "${aws_subnet.private-subnet.id}"
  root_block_device {
     delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname master.${var.domain}",
      "echo PEERS= | sudo tee /etc/sysconfig/weave",
      "echo MYIP=${self.private_ip} | sudo tee /tmp/vars.sh",
      "echo CONSUL_MASTER=${self.private_ip} | sudo tee -a /tmp/vars.sh"
    ]
  }
  
  provisioner "file" {
    source = "provision/sys.sh"
    destination = "/tmp/sys.sh"
  }
  
  provisioner "file" {
    source = "provision/docker.sh"
    destination = "/tmp/docker.sh"
  }
  
  provisioner "file" {
    source = "provision/mesos-master.sh"
    destination = "/tmp/mesos-master.sh"
  }
  
  provisioner "file" {
    source = "provision/consul.sh"
    destination = "/tmp/consul.sh"
  }
  
  provisioner "file" {
    source = "provision/vulcand.sh"
    destination = "/tmp/vulcand.sh"
  }
  
  provisioner "file" {
    source = "provision/dnsmasq.sh"
    destination = "/tmp/dnsmasq.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sh /tmp/sys.sh",
      "sh /tmp/docker.sh",
      "sh /tmp/consul.sh",
      "sh /tmp/vulcand.sh",
      "sh /tmp/mesos-master.sh",
      "sh /tmp/dnsmasq.sh"
    ]
  }
}

resource "aws_instance" "slave" {
  connection {
    user = "centos"
  }

  count = 3

  tags {
        Name = "slave${count.index}"
  }

  instance_type = "${var.aws_slave_instance_size}"
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  key_name = "${aws_key_pair.showcase.id}"
  vpc_security_group_ids = ["${aws_security_group.slave_sg.id}"]
  subnet_id = "${aws_subnet.private-subnet.id}"
  depends_on = ["aws_instance.master"]
  root_block_device {
     delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname slave${count.index}.${var.domain}",
      "echo PEERS=${aws_instance.master.private_ip} | sudo tee /etc/sysconfig/weave",
      "echo MYIP=${self.private_ip} | sudo tee /tmp/vars.sh",
      "echo MASTER_IP=${aws_instance.master.private_ip} | sudo tee -a /tmp/vars.sh",
      "echo CONSUL_MASTER=${aws_instance.master.private_ip} | sudo tee -a /tmp/vars.sh"
    ]
  }
  
  provisioner "file" {
    source = "provision/sys.sh"
    destination = "/tmp/sys.sh"
  }
  
  provisioner "file" {
    source = "provision/docker.sh"
    destination = "/tmp/docker.sh"
  }
  
  provisioner "file" {
    source = "provision/mesos-slave.sh"
    destination = "/tmp/mesos-slave.sh"
  }
  
  provisioner "file" {
    source = "provision/consul-slave.sh"
    destination = "/tmp/consul-slave.sh"
  }
  
  provisioner "file" {
    source = "provision/dnsmasq.sh"
    destination = "/tmp/dnsmasq.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sh /tmp/sys.sh",
      "sh /tmp/docker.sh",
      "sh /tmp/mesos-slave.sh",
      "sh /tmp/consul-slave.sh",
      "sh /tmp/dnsmasq.sh"
    ]
  }
}
