#!/bin/bash
exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

# this is the commun code section
# Update and install dependencies
sudo apt update -y
sudo apt-get install -y sysbench unzip

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

# manager code
# Create directories and configuration files
mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
mkdir conf
mkdir mysqld_data
mkdir ndb_data
cd conf 

# Create the my.cnf file
echo -e "
[mysqld]
ndbcluster
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
port=3306" > my.cnf

# create the config.ini
echo -e "# for the master
[ndb_mgmd]
hostname=ip-172-31-20-0.ec2.internal
datadir=/opt/mysqlcluster/deploy/ndb_data
nodeid=1

[ndbd default]
noofreplicas=3
datadir=/opt/mysqlcluster/deploy/ndb_data

# for slave #1
[ndbd]
hostname=ip-172-31-20-1.ec2.internal
nodeid=2

#for slave #2
[ndbd]
hostname=ip-172-31-20-2.ec2.internal
nodeid=3

#for slave #3
[ndbd]
hostname=ip-172-31-20-3.ec2.internal
nodeid=4

[mysqld]
nodeid=50" > config.ini

# Start MySQL Server
cd /opt/mysqlcluster/home/mysqlc
# Initialize the database
sudo scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data

sudo chown -R mysql:mysql /opt/mysqlcluster/home/mysqlc

# Start management node
sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/
#ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/

# check status of management data nodes
ndb_mgm -e show

# start the sql node
mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &

ndb_mgm -e show