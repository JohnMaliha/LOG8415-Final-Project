#!/bin/bash
exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

# Update and install dependencies
sudo apt update -y
sudo apt upgrade -y
sudo apt-get install -y libncurses5 sysbench unzip

# Add MySQL user if not exists
if ! id "mysql" &>/dev/null; then
    sudo useradd -r -s /bin/false mysql
fi

# Download and install MySQL Cluster
mkdir -p /opt/mysqlcluster/home
cd /opt/mysqlcluster/home
wget http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc

# Set environment variables
echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' > /etc/profile.d/mysqlc.sh
echo 'export PATH=$MYSQLC_HOME/bin:$PATH' >> /etc/profile.d/mysqlc.sh
echo 'export PATH=/opt/mysqlcluster/home/mysqlc/bin:$PATH' >> /opt/mysqlcluster/home/mysqlc/bin
source /etc/profile.d/mysqlc.sh

# Create directories and configuration files
mkdir -p /opt/mysqlcluster/deploy/{conf,mysqld_data,ndb_data}
cd /opt/mysqlcluster/deploy/conf

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

# Start management node
sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf || exit 1

# Initialize the database
# sudo /opt/mysqlcluster/home/mysqlc/scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data
sudo /opt/mysqlcluster/home/mysqlc/scripts/mysql_install_db --no-defaults --basedir=/opt/mysqlcluster/home/mysqlc --datadir=/opt/mysqlcluster/deploy/mysqld_data


# Start MySQL Server
cd /opt/mysqlcluster/home/mysqlc
sudo scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data
# sudo /opt/mysqlcluster/home/mysqlc/bin/mysqld_safe &

# create ngmd 
# sudo nano /etc/systemd/system/ndb_mgmd.service
echo "[Unit]
Description=MySQL Cluster Management Node
After=network.target

[Service]
Type=forking
ExecStart=/opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --configdir=/opt/mysqlcluster/deploy/conf
ExecStop=/opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd --shutdown
User=mysql
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/ndb_mgmd.service

# restart then start the ndb_mgmd
sudo systemctl daemon-reload
sudo systemctl enable ndb_mgmd
sudo systemctl start ndb_mgmd
sudo systemctl status ndb_mgmd

# Wait for MySQL Server to start (better check)
sleep 10

# Download and extract Sakila DB
wget https://downloads.mysql.com/docs/sakila-db.zip
unzip sakila-db.zip -d /db

# Load Sakila Database
