#!/bin/bash

exec > /home/ubuntu/logs.log 2>&1 # tail -f logs.log

sudo apt-get update -y
#installing dependencies 
sudo apt-get install -y unzip
#installing mysql
sudo apt-get install -y mysql-server
# instal sysbench for benchmarking
sudo apt-get install -y sysbench

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

# creates
mysql sakila -e "SHOW FULL TABLES;"
mysql sakila -e "SELECT COUNT(*) FROM film;"

# run sysbench
# The commands given to us in the tutoriel were not working for me, (decapritaded) therefore i found this:
# https://webhostinggeeks.com/howto/how-to-use-sysbench-to-test-database-performance-on-a-linux-machine/
# I did not set a mysql password.
# prepare the tests by creating a table with 1000000 data entry points.
sudo sysbench /usr/share/sysbench/oltp_read_write.lua prepare --db-driver=mysql --mysql-db=sakila --mysql-user=root --mysql-password --table-size=1000000 

# Run the tests in order to test performance. and write it to a file.
sudo sysbench /usr/share/sysbench/oltp_read_write.lua run --db-driver=mysql --mysql-db=sakila --mysql-user=root --mysql-password --table-size=1000000 --threads=6 --time=60 --events=0 > mysqlstandalone

# cleanup after the benchmark.
sudo sysbench /usr/share/sysbench/oltp_read_write.lua cleanup --db-driver=mysql --mysql-db=sakila --mysql-user=root --mysql-password
