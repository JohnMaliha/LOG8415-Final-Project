#!/bin/bash

# install docker
yum update -y

sudo yum install -y yum-utils

yum install -y docker

sudo usermod -a -G docker ec2-user

# start docker
sudo systemctl start docker

# get our dockerfile to run the container
sudo docker pull therealflash/proxy:latest

# get the instance id
export INSTANCE_ID=$(ec2-metadata --instance-id)

sudo docker run -e INSTANCE_ID="$INSTANCE_ID" -p 80:5000 therealflash/proxy:latest