#!/bin/bash
exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

# this is the commun code section
# Update and install dependencies
sudo apt update -y
sudo apt-get install -y sysbench unzip expect

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
hostname=ip-172-31-26-0.ec2.internal
datadir=/opt/mysqlcluster/deploy/ndb_data
nodeid=1

[ndbd default]
noofreplicas=3
datadir=/opt/mysqlcluster/deploy/ndb_data

# for slave #1
[ndbd]
hostname=ip-172-31-26-1.ec2.internal
nodeid=2

#for slave #2
[ndbd]
hostname=ip-172-31-26-2.ec2.internal
nodeid=3

#for slave #3
[ndbd]
hostname=ip-172-31-26-3.ec2.internal
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
# ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/

# check status of management data nodes
ndb_mgm -e show

# start the sql node
mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &

# Increase sleep time to ensure MySQL is ready
sleep 10

ndb_mgm -e show

# Automate mysql_secure_installation
cat > ~/install_secure_mysql.sh >/dev/null << EOF
#!/usr/bin/expect
set timeout 20

spawn $(which mysql_secure_installation)
expect "Enter current password for root (enter for none):"
send "root\r"
expect "Set root password? \\[Y/n\\]"
send "n\r"
expect "Remove anonymous users? \\[Y/n\\]"
send "y\r"
expect "Disallow root login remotely? \\[Y/n\\]"
send "y\r"
expect "Remove test database and access to it? \\[Y/n\\]"
send "y\r"
expect "Reload privilege tables now? \\[Y/n\\]"
send "y\r"
expect eof
EOF

# Change the owner to root and make the script executable
sudo chown root:root ~/install_secure_mysql.sh
sudo chmod 4755 ~/install_secure_mysql.sh

# Execute the script
sudo ~/install_secure_mysql.sh

#remove the script after execution
#rm -f -v ~/install_secure_mysql.sh

# ---- shameless copy paste form chat-gpt---------------- #
# wait to ensure MySQL is ready
while ! mysqladmin ping --silent; do
    sleep 1
done
# --------------------------------------------------------- #
ndb_mgm -e show

# install sakila db
cd ~
wget https://downloads.mysql.com/docs/sakila-db.zip
unzip sakila-db.zip -d /db

mysql -u root -e  "SOURCE /db/sakila-db/sakila-schema.sql"
mysql -u root -e  "SOURCE /db/sakila-db/sakila-data.sql"

# lets make sur it installs correctly!
mysql -u root -e "USE sakila; SHOW FULL TABLES;"
mysql -u root -e "USE sakila; SELECT COUNT(*) FROM film;"

# grant privileges.
mysql -u root -e "GRANT ALL PRIVILEGES ON sakila.* TO 'root'@'%' IDENTIFIED BY '' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES"

# run sysbench
sudo sysbench /usr/share/sysbench/oltp_read_write.lua prepare --db-driver=mysql --mysql-host=ip-172-31-26-0.ec2.internal --mysql-db=sakila --mysql-user=root --mysql-password --table-size=1000000 

# Run the tests in order to test performance. and write it to a file.
sudo sysbench /usr/share/sysbench/oltp_read_write.lua run --db-driver=mysql --mysql-host=ip-172-31-26-0.ec2.internal --mysql-db=sakila --mysql-user=root --mysql-password --table-size=1000000 --threads=6 --time=60 --events=0 

# cleanup after the benchmark.
sudo sysbench /usr/share/sysbench/oltp_read_write.lua cleanup --db-driver=mysql --mysql-host=ip-172-31-26-0.ec2.internal --mysql-db=sakila --mysql-user=root --mysql-password