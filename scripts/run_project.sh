#!/bin/bash

set -e  # stop script if any command fails
set -x  # print each command before executing

echo "Creating images"
sh create_proxy_docker.sh
sh create_trusted_host_docker.sh
sh create_gatekeeper_docker.sh
# sh create_requests_docker.sh

sh create_terraform.sh 
echo "Build success!"