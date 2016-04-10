#!/bin/bash

curl -i -X POST \
  --url http://localhost:8001/apis/ \
  --data 'name=mesos-leader' \
  --data 'upstream_url=http://mesos.service.consul:5050' \
  --data 'request_host=mesos.service.consul'

curl -i -X POST \
  --url http://localhost:8001/apis/ \
  --data 'name=marathon-leader' \
  --data 'upstream_url=http://marathon.service.consul:8080' \
  --data 'request_host=marathon.service.consul'
