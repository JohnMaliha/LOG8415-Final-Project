#!/bin/bash
exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

# this is the commun code section
# Update and install dependencies
sudo apt update -y
sudo apt-get install -y sysbench

# Download and install MySQL Cluster
mkdir -p /opt/mysqlcluster/home
cd /opt/mysqlcluster/home
wget http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc

# Set environment variables
echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' > /etc/profile.d/mysqlc.sh
echo 'export PATH=$MYSQLC_HOME/bin:$PATH' >> /etc/profile.d/mysqlc.sh
source /etc/profile.d/mysqlc.sh
sudo apt-get update && sudo apt-get -y install libncurses5

mkdir -p /opt/mysqlcluster/deploy/ndb_data
# start up Data Node with the address of the manager
ndbd -c ip-172-31-27-0.ec2.internal:1186 # 1186 default port 

# check status of management data nodes
ndb_mgm -e show