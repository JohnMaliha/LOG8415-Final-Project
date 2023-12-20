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
# data "aws_vpc" "default" {
#   default = true
# }

# I wanted to use hardcoded addrs. So we definie a vpc.
resource "aws_vpc" "default" {
  cidr_block       = "172.31.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "main_vpc"
  }
}

# the subnet i chose is 24/23 so it goes from X.X.24.255 to X.X.25.255.
# i wanted to have addresses that end with 0.
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "172.31.24.0/23"
  availability_zone = "us-east-1a"
  tags = {
    Name = "main_subnet"
  }
}

# create security group
resource "aws_security_group" "final_projet_security_group" {
  name        = "final_projet_security_group"
  description = "Allow traffic to the t2 mysql sandalone"
  vpc_id      = aws_vpc.default.id
  
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
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"  
  user_data = file("mysql_cluster_manager.sh") # used to run script which deploys docker container on each instance
  subnet_id = aws_subnet.main.id
  private_ip = "172.31.25.0" # manually give ips addresses to each instances.
    tags = {
    Name = "t2_mysql_cluster_manager"
  } 
}

# create 3 t2 micro mysql_clusters workers instances
resource "aws_instance" "t2_mysql_worker1" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"
  user_data = file("mysql_cluster_workers.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.1"
    tags = {
    Name = "t2_mysql_cluster_worker1"
  } 
}

resource "aws_instance" "t2_mysql_worker2" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"
  user_data = file("mysql_cluster_workers.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.2"
    tags = {
    Name = "t2_mysql_cluster_worker2"
  } 
}

resource "aws_instance" "t2_mysql_worker3" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.micro"
  user_data = file("mysql_cluster_workers.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.3"
    tags = {
    Name = "t2_mysql_cluster_worker3"
  } 
}

# t2 large for the proxy
resource "aws_instance" "proxy" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.large"
  user_data = file("proxy.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.4"
    tags = {
    Name = "t2_proxy"
  } 
}

resource "aws_instance" "gatekeeper" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.large"
  user_data = file("gatekeeper.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.5"
    tags = {
    Name = "t2_gatekeeper"
  } 
}

resource "aws_instance" "trusted_host" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.large"
  user_data = file("trusted_host.sh") # used to run script which deploys docker container on each instance
  subnet_id     = aws_subnet.main.id
  private_ip = "172.31.25.6"
    tags = {
    Name = "t2_trusted_host"
  } 
}

# # output the instance ids for the workers
# output "t2_instance" {
#   value = [for instance in aws_instance.t2_mysql_workers: instance.id]
# }