#!/bin/bash
exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

# Inspired from this link : https://stansantiago.wordpress.com/2012/01/04/installing-mysql-cluster-on-ec2/

cd ~;
#installing dependencies
sudo apt update -y
sudo apt upgrade -y
sudo apt-get install -y libncurses5
sudo apt-get install sysbench
sudo apt-get install -y unzip

# Download and then install MySQL cluster
mkdir -p /opt/mysqlcluster/home
cd /opt/mysqlcluster/home
wget http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc

echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' > /etc/profile.d/mysqlc.sh
echo 'export PATH=$MYSQLC_HOME/bin:$PATH' >> /etc/profile.d/mysqlc.sh
source /etc/profile.d/mysqlc.sh 

# Create the Deployment Directory and Setup Config Files
mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
mkdir conf
mkdir mysqld_data
mkdir ndb_data
cd conf

# Create the my.cnf file
echo "[mysqld]
ndbcluster
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
port=3306" > my.cnf

# create the config.ini
echo "
# for the master
[ndb_mgmd]
hostname=ip-172-31-42-0.ec2.internal
datadir=/opt/mysqlcluster/deploy/ndb_data
nodeid=1

[ndbd default]
noofreplicas=3
datadir=/opt/mysqlcluster/deploy/ndb_data

# for slave #1
[ndbd]
hostname=ip-172-31-42-1.ec2.internal
nodeid=2

#for slave #2
[ndbd]
hostname=ip-172-31-42-2.ec2.internal
nodeid=3

#for slave #3
[ndbd]
hostname=ip-172-31-42-3.ec2.internal
nodeid=4

[mysqld]
nodeid=50
" > config.ini

mkdir -p /opt/mysqlcluster/deploy/ndb_data
# start up Data Node
ndbd -c ip-172-31-42-0.ec2.internal