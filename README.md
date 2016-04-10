# Basic microservices environment automation


This repository showcases a basic cloud environment to deploy microservices in.

It is not intended as a production ready solution, but as a baseline to learn about common technologies like:

* Mesos/Marathon: service orchestration
* Consul: service discovery
* Vulcan: microservice routing
* Kong: public gateway to microservices
* Terraform: describe and apply your infrastructure and operations
* AWS: your infrastructure provider

WARNING: This code will generate a AWS VPC and a few EC2 instances. Make sure you understand the associated costs before running any of this.

## Requirements

To get started, you will need to set your local environment first:

First, create a AWS account (please, make sure to create a dedicated IAM account, do not use your root account)

### AWS Credentials

Create an access key for your IAM user and store it onto your disk for now

Setup now your AWS credentials onto your system, if you have [awscli](https://aws.amazon.com/cli/?nc1=h_ls), you simply run:

```sh
$ aws configure --profile showcase
AWS Access Key ID [None]: XXXX
AWS Secret Access Key [None]: XXX
Default region name [None]: eu-west-1a
Default output format [None]: json
```

Replace the values with the ones that suit you.

If you don't want to install awscli, you may simply create two files:

```sh
cat <<EOF | tee -a ~/.aws/credentials
[showcase]
aws_access_key_id = XXX
aws_secret_access_key = XXX
EOF
```

```sh
cat <<EOF | tee -a ~/.aws/config
[profile showcase]
output = json
region = eu-west-1
EOF
```

### SSH key

Create now a SSH key:

```sh
$ ssh-keygen -t rsa -b 2048 -C "showcase" -P '' -f ~/.ssh/showcase
```

Ensure, the private key is known to your current session:

```sh
$ eval $(ssh-agent -s)
$ ssh-add  ~/.ssh/showcase
```

Make sure to always add your ssh identity like this when you open a new terminal.


### Terraform

Once your credentials are configured properly, you can move on to install [Terraform](https://www.terraform.io/downloads.html).

This is basically a set of binaries that should be decompressed into a local directory. Make that directory available to your `PATH`.


## Overview

The AWS infrastructure generated by this recipe will be as follows:

* One VPC
* Two subnets:
  - A public subnet: 10.0.5.0/24
  - A private subnet: 10.0.12.0/24
* The EC2 instances are, by default, `t2.medium`
* The OS used is a [CentOS 7 from the AWS AMI market-place](https://aws.amazon.com/marketplace/pp/B00O7WM7QW)
* The default region and availibility zone arr respectively `eu-west-1` and `eu-west-1a`
* Internally, services will register to the `service.consul` domain


The public and private subnets are mostly to demonstrate how to isolet your networks based on the services you are running. The public service should be the one bridging between the outside world and your private network. Few services should be running there, mostly the public gateway that will dispatch to the router running on the private network.

In production, you would likely even have more networks. But this is a baseline example.
Obviously, this means that the security groups will differ between both networks.

You may change most of those settings through the terraform variables.

Notice that this will not create a AWS ELB because we are using Kong for this.

Once the cluster is created, terraform will display a bunch of IP variables in the console. They will help you connect to the instances and services. You can also retrieve them from the AWS console as well.

You should add the following line to your `/etc/hosts`:

```sh
$ echo "<public kong address>  kong.service.consul" | sudo tee -a /etc/hosts
```


## Deploy your cluster

Creating the cluster is as simple as the next command:

```sh
$ terraform apply -var 'key_name=showcase' -var 'public_key_path=~/.ssh/showcae.pub'
```

You may specify a different ssh key or a different name for it. The key will be imported into your AWS account by terraform.

If you want to override other settings, look at the file named `variables.tf` and pass any variable to the command line or edit that file.

Note that terraform is incremental, if you add a new resource, it will recompute everything
and apply only the modifications (sometimes, this will re-create instances, so becareful).


## Destroy your cluster

You may destroy your cluster as follows:

```sh
$ terraform destroy -var 'key_name=showcase' -var 'public_key_path=~/.ssh/showcae.pub'
```

This will ask you to confirm before destroying all the resources that were created.
This cannot be reversed.


## Cluster services

When your cluster is running, it executes the following services:

* [kong](https://getkong.org/): the public gateway
* [vulcand](http://vulcand.github.io/): the internal router
* [consul](https://www.consul.io/) the internal service discovery and DNS server
* [mesos](http://mesos.apache.org/) the resource sharing service
* [marathon](https://mesosphere.github.io/marathon/) the service orchestration
* [docker](https://www.docker.com/) the microservice container
* [weave](https://www.weave.works/) the overlay network

The containers are configured so that they resolve names on the `service.consul` domain first. Otherwise, the host's dnsmasq pushes the request to the AWS DNS. We don't use the weave built-in DNS because Consul offers a richer interface and is rather easily accessible from both host and containers.

### Register Mesos/Marathon services to the gateway

Before you can access mesos and marathon from the outsie world, they both need to be registered to the gateway (kong). To do so, you must connect to the kong host via ssh:

```sh
$ ssh centos@kong.service.consul
```

Then run these commands from the remote host:

```sh
[centos@kong ~]$ sudo sh /tmp/register-mesos-marathon-services.sh
```

Now add `mesos.service.consul` and `marathon.service.consul` domains to your `/etc/hosts` using the kong public IP address. For instance you could have a line like this:

```
<PUBLIC IP>    mesos.service.consul marathon.service.consul kong.service.consul
```

The reason we re-use the same IP is that all the traffic goes through Kong which then dispatches based on the request's host. In  production, you would obviously rely on a properly configured DNS that would point to your gateway server. This is just a showcase ;)

You can now connect to:

* Mesos UI: http://mesos.service.consul:8000
* Marathon UI: http://marathon.service.consul:8000/ui/




## Run a microservice in your cluster

### Schedule a new microservice via Marathon

You can easily create a service via the Marathon's UI or push a spec to the service as follows:

```sh
$ curl -XPOST -H 'Content-Type: application/json' --data-binary @specs/app.json http://marathon.service.consul:8000/v2/apps
```

At that stage, however your microservice is not yet visible from the outside world. To achieve this, we must populate the discovery service, the router and the gateway.

### Register the microservice so that it is publicly and internally available

Once your microservice is running, you must expose it to the rest of the world. First, we declare the service against the gateway, the router and the service discovery:

```sh
[centos@kong ~]$ ./register-service.sh --service-name=web --service-port=10000
```

The service port is the one given to you by Marathon when you scheduled the application.

Next, we also register each instance as servers to the router's backends for that service:

```sh
[centos@kong ~]$ ./register-instance.sh --service-id=web1 --service-name=web --host-address=10.0.12.223 --host-port=53769
```

Change the address and port according to what Marathon chose. The service id can be anything but must be unique.

That's it!

Add `web.service.consul` to your `/etc/hosts` like before and connect from your browser to http://web.service.consul:8000/

Tada!

### Scale up your service

If you want to add more instances to handle the load, simply use Marathon to scale up your microservice and register each instance to the router's backend using a different service id, for example:

```sh
[centos@kong ~]$ ./register-instance.sh --service-id=web2 --service-name=web --host-address=1à.0.12.67 --host-port=57540
```

Now, your service will hit both instances alternatively.


### Scale down your service

You can reduce the number of running instance, or remove a broken instance:

```sh
[centos@kong ~]$ ./deregister-instance.sh --service-id=web2 --service-name=web 
```

### Deregister your service

When your service is not needed anylonger, you can simply deregister everything from the gateway, the router and the service discovery:

```sh
[centos@kong ~]$ ./deregister-service.sh --service-name=web 
```


## Limitations

### Dynamic service registry

For now, unfortunately, having those services doesn't mean they will be populated dynamically whenever you start a microservice via marathon. Indeed, there is no native tool that binds all of them nicely.

The general principle would be to react from [Marathon events](https://mesosphere.github.io/marathon/docs/event-bus.html) and register to Consul, Vulcand and Kong. All those services expose nice REST API so it's eeasy enough from their end. The difficulty lies in the events sent out by Marathon which don't make it straightforward.

First, there are different pieces of information we need, the microservices host port, the service port, the hostname of the microservice. But, those pieces of information are scattered across different event types. That would be fine if thsoe events were received in the right order, but they aren't. B y "right order", I mean to say when you receive the `TASK_RUNNING` event for example, which contains the host port of the running microservice's instance, you may not know the hostname of the microservice yet so you can't register it to any of the services.

In some cases, like when you restart the instance from Marathon's UI, you may not even receive all events, just the task's status event. In that case, you wouldn't know which service to aim for with consul, kong or vulcand.

Due to this, you can't easily write a dispatching service that listen to Marathon's events and call other services accordingly.

What this means for now is that you must register to all those services "manually" when you have started your microservice via Marathon.
