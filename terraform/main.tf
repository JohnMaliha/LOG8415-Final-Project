terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# connect to aws
provider "aws" {
  region = "us-east-1"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  token = "${var.token}"
}

# create vpc
data "aws_vpc" "default" {
  default = true
}

# create security group
resource "aws_security_group" "final_projet_security_group" {
  name        = "final_projet_security_group"
  description = "Allow traffic to the t2 mysql sandalone"
  vpc_id      = data.aws_vpc.default.id
  
  # Define your security group rules here
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create 1 t2.micro mysql standalone instance
resource "aws_instance" "t2_mysql_standalone" {
  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"
  user_data = file("mysql_standalone.sh") # used to run script which deploys docker container on each instance
  tags = {
    Name = "t2_mysql_standalone"
  }
}

# create 1 t2 micro mysql_clusters manager instances
resource "aws_instance" "t2_mysql_manager" {
  count         = 0
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "m4.large"
  user_data = file("mysql_worker_manager.sh") # used to run script which deploys docker container on each instance
    tags = {
    Name = "t2_mysql_manager"
  } 
}

# create 3 t2 micro mysql_clusters workers instances
resource "aws_instance" "t2_mysql_workers" {
  count         = 0
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"
  user_data = file("mysql_worker_workers.sh") # used to run script which deploys docker container on each instance
    tags = {
    Name = "mysql_worker_workers"
  } 
}

# output the instance ids for the workers
output "t2_instance" {
  value = [for instance in aws_instance.t2_mysql_workers: instance.id]
}