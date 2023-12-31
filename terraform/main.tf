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
  # token = "${var.token}"
}

# create vpc
data "aws_vpc" "default" {
  default = true
}

# create security group for each instances. I allow every connections and ports (simplicity purposes)
# In a real world senario it should be safer.
resource "aws_security_group" "final_projet_security_group" {
  name        = "final_projet_security_group"
  description = "Allow traffic to the t2 mysql"
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

 # I created a security group that allows only via tcp the gatekeeper to connect to the trusted host.
 # Port 22 (tcp) and port 80 (docker runs on port 80)
 # I have 2 ingress rules because i want to open only port 22 and only port 80.
resource "aws_security_group" "final_projet_security_group_trusted_host" {
  name        = "final_projet_security_group_trusted_host"
  description = "Allow traffic to the trusted group"
  vpc_id      = data.aws_vpc.default.id
  
  # Define your security group rules here
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.31.50.248/32"] # private ip of the gatekeeper. the trusted host one gets requests from the gatekeeper.
  }
   ingress {
    from_port   = 80 # for when we bind the trusted host via http. (remote_bind_address=(trusted_host_dns, 80))
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.31.50.248/32"]
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
  availability_zone = "us-east-1e"
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
  availability_zone = "us-east-1e"
  private_ip = "172.31.57.56" # manually give ips addresses to each instances.
  key_name = "final_assignment"
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
  availability_zone = "us-east-1e"
  private_ip = "172.31.57.116"
  key_name = "final_assignment"
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
  availability_zone = "us-east-1e"
  private_ip = "172.31.57.86"
  key_name = "final_assignment"
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
  availability_zone = "us-east-1e"
  private_ip = "172.31.57.192"
  key_name = "final_assignment"
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
  availability_zone = "us-east-1e"
  key_name = "final_assignment" # links to the ssh key. 
    tags = {
    Name = "t2_proxy"
  } 
}

# create 1 t2.large instance for the gatekeeper.
resource "aws_instance" "gatekeeper" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group.id]
  instance_type = "t2.large"
  user_data = file("gatekeeper.sh") # used to run script which deploys docker container on each instance
  availability_zone = "us-east-1e"
  private_ip = "172.31.50.248"
  key_name = "final_assignment"

    tags = {
    Name = "t2_gatekeeper"
  } 
}

# create 1 t2.large instance for the trusted host. 
# The security group differs from the others because we want it to be secure (only the gatekeeper can send requests to the trusted host.)
resource "aws_instance" "trusted_host" {
  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_projet_security_group_trusted_host.id]
  instance_type = "t2.large"
  user_data = file("trusted_host.sh") # used to run script which deploys docker container on each instance
  availability_zone = "us-east-1e"
  private_ip = "172.31.57.52"
  key_name = "final_assignment"
    tags = {
    Name = "t2_trusted_host"
  } 
}