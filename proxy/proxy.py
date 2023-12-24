import random
import boto3
import pymysql

from flask import Flask, request
from sshtunnel import SSHTunnelForwarder
from pythonping import ping

from credentials import * 

app = Flask(__name__)
app.debug =True

session = boto3.Session(
    aws_access_key_id = access_key,
    aws_secret_access_key = secret_key,
    aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')

# Getting dynamically the ips for the workers and manager.
def get_manager_ips():
    manager_list = []
    workers_id = ec2_resource.instances.filter(Filters=[
        {'Name': 'tag:Name', 'Values': ['t2_mysql_cluster_manager']}, 
        {'Name': 'instance-state-name', 'Values': ['running']}
    ])
    for worker in workers_id:
        manager_list.append(worker.public_ip_address)
    return manager_list[0]

# get managerIP
def get_workers_ips():
    worker_list = []
    all_workers_list = ec2_resource.instances.filter(Filters=[
        {'Name': 'tag:Name', 'Values': ['t2_mysql_cluster_worker1','t2_mysql_cluster_worker2','t2_mysql_cluster_worker3']},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ])
    for worker in all_workers_list:
        worker_list.append(worker.public_ip_address)
    return worker_list

# Create an ssh tunnel and establish connection to the servers. 
# Takes three params. ip of the manager nodes and data nodes. last param is the query.
# the only param we can decide is the sql query.
def ssh_connection_handler(manager_ip,worker_ip,sql_query):
    resp = "Response from the manager/data nodes : \n"
    if not manager_ip:
        raise Exception("Manager IP is required")
    
    with SSHTunnelForwarder(
        (worker_ip,22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(manager_ip, 3306),
        #local_bind_address=('0.0.0.0', 5000)
    ) as tunnel:
        
        # connect to the sakila db using mysql via the tunnel
        connection = pymysql.connect(
            host=manager_ip, 
            user='root',
            password='', # i did not set any passwords for my sakila db.
            db='sakila',
            port=3306,
            autocommit=True
    )

    try:
        with connection.cursor() as cursor:
            print(f"Connection to data-master nodes : Tunnel established to manager node {manager_ip} and data node : {worker_ip} Local port: {3306}. The query is {sql_query}")
            cursor.execute(sql_query)
            response = cursor.fetchall()
            for row in response: 
                resp = resp + str(row)
                print(resp)
    except Exception as e:
        print(f"Connection to data-master nodes : error establishing SSH tunnel: {e}")
    finally:
        connection.close()
        print("Connection to data-master nodes : Tunnel closed")
    return resp

# Returns a random worker for random hit
def get_random_worker(workers):
    return random.choice(workers)


def find_speed_of_workers_ms(worker_ip):
    try:
        response = ping(worker_ip, count=1, timeout=1)
        if response.success():
            # The attrib rrt_avg_ms returns the ping time.
            # https://stackoverflow.com/questions/67476432/pythong-get-ping-time-using-pythonping-module
            avg_time_ms = response.rtt_avg_ms
            # print(avg_time_ms)
            return avg_time_ms
        else:
            return None
    except Exception as e:
        print(f"No response was returned: {e}")
        return None

# takes all the workers and mesures their response time. 
# returns the fastest worker.
def find_fastest_worker_node(all_workers):
    min_avg_time = float('inf')

    for worker in all_workers:
        avg_time = find_speed_of_workers_ms(worker)
        if avg_time < min_avg_time:
            min_avg_time = avg_time
            fastest_node = worker
    return fastest_node,min_avg_time

# convert the ip address to string
def to_string_ip(ip_address):
    return str(ip_address)

@app.route("/")
def default():
    return '<h1> Select one of the above proxy implementation : 1) /direct-hit 2) /random-hit 3) /customized-hit </h1>'

@app.route('/manager')
def manager():
    manager_ip = get_manager_ips()
    return "Manager IP: " + str(manager_ip)

@app.route('/workers')
def worker():
    worker_ip = get_workers_ips()
    return "worker IP: " + str(worker_ip)

# ----------------- Proxy methods ------------------------------------# 
# For all the proxy patterns implementations here is an example of the url : 
# http://ADDRESS:PORT/PROXY_METHOD?query=YOURSQLQUERY;

# Direct-hit proxy : imedietly send the request to the master(manager) node. 
@app.route('/direct-hit')
def direct_hit():
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    print(f"Proxy direct-hit \n Sending request to : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=manager_ip,sql_query=query_params)

# Random-hit proxy is randomly choosing a worker node and sending the request to that node.
@app.route('/random-hit')
def random_hit():
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    worker_ip = get_random_worker(get_workers_ips())
    print(f"Proxy random-hit \n Sending request to worker : {worker_ip} where manager node : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=worker_ip,sql_query=query_params)
 

# Customized-hit proxy is choosing the worker node with the lowest latency and sending the request to that worker node.
@app.route('/custom-hit')
def customized():
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    worker_ip_list = get_workers_ips()
    fastest_worker_ip,ping_time = find_fastest_worker_node(worker_ip_list)
    print(f"Proxy custom-hit \n Sending request to fastest worker : {fastest_worker_ip} with ping response time : {ping_time} where manager node : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=fastest_worker_ip,sql_query=query_params)
    

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)