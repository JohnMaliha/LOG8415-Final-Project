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
ndbd -c ip-172-31-42-0.ec2.internal:1186 # 1186 default port 

# MAX_ATTEMPTS=30
# ATTEMPT=0
# SUCCESS=false

# # Loop to check status
# while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
#     # Check status
#     if ndb_mgm -e show | grep -q "connected"; then
#         SUCCESS=true
#         break
#     fi

#     ATTEMPT=$((ATTEMPT+1))
#     sleep 10
# done

# if [ "$SUCCESS" = true ]; then
#     echo "All nodes are successfully connected."
# else
#     echo "Failed to connect all nodes within the expected time."
#     exit 1
# fi

# check status of management data nodes
ndb_mgm -e show