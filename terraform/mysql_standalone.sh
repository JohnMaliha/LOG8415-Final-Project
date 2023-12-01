#!/bin/bash

exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

sudo apt-get update -y
#installing dependencies 
sudo apt-get install -y unzip
#installing mysql
sudo apt-get install -y mysql-server
# instal sysbench for benchmarking
apt-get install sysbench

cd ~ # ~ = home/ubuntu
#security for mysql.
# https://stackoverflow.com/questions/20760908/what-is-purpose-of-using-mysql-secure-installation
# As we will only leave the instances running for a couple of minutues to benchmark, i feel like it is not necessary.
#sudo mysql_secure_installation 

# lets get the sakilaDB installation files: 
# From this website we take : https://dev.mysql.com/doc/index-other.html 
# We want the sakila database available at this link. 
wget https://downloads.mysql.com/docs/sakila-db.zip
unzip sakila-db.zip -d /db

# mysql -e "SOURCE /db/sakila-db/sakila-schema.sql;"
# mysql -e "SOURCE /db/sakila-db/sakila-data.sql;"

mysql < /db/sakila-db/sakila-schema.sql
mysql < /db/sakila-db/sakila-data.sql

# Did it get created?
mysql sakila -e "SHOW FULL TABLES;"
mysql sakila -e "SELECT COUNT(*) FROM film;"