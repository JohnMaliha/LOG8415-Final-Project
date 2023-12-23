#!/bin/bash

set -e  # stop script if any command fails
set -x  # print each command before executing

echo "Creating images"
sh create_gatekeeper_docker.sh 
sh create_proxy_docker.sh
sh create_gatekeeper_docker.sh
sh create_trusted_host_docker.sh

sh create_terraform.sh  # create terraform IaC
sh create_docker_requests.sh # create docker image for requests
echo "Build success!"