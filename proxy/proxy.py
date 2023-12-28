import random
import boto3
import pymysql

from flask import Flask, request
from sshtunnel import SSHTunnelForwarder
from pythonping import ping

from credentials import * 

app = Flask(__name__)
app.debug =False # for debugging

session = boto3.Session(
    aws_access_key_id = access_key,
    aws_secret_access_key = secret_key,
    # aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')

# Getting dynamically the ips for the workers and manager.
def get_manager_ips():
    """
    Retrieve the IP address of the first running AWS EC2 instance tagged as a MySQL cluster manager.

    This function filters AWS EC2 instances with the tag 't2_mysql_cluster_manager' and 
    state 'running', and extracts the public IP address of the first instance in this filtered list.

    Returns:
    str: The public IP address of the first (and the only one) running  MySQL cluster manager instance.
    """
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
    """
    Retrieve the IP addresses of running AWS EC2 instances tagged as MySQL cluster workers.

    This function filters AWS EC2 instances with tags 't2_mysql_cluster_worker1', 
    't2_mysql_cluster_worker2', and 't2_mysql_cluster_worker3' in a 'running' state, 
    and collects their public IP addresses.

    Returns:
    list: A list of public IP addresses of the running MySQL cluster worker instances.
    """
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
    """
    Establish an SSH tunnel and execute an SQL query on a MySQL cluster.

    This function sets up an SSH tunnel to a specified worker node, then connects to a MySQL 
    database on the manager node and executes the provided SQL query. It returns the query response.

    Args:
    manager_ip (str): The IP address of the manager node.
    worker_ip (str): The IP address of the worker node to tunnel through.
    sql_query (str): The SQL query to execute.

    Returns:
    str: The response from executing the SQL query.
    """

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
            # response.json()  
            # json.dumps()
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
    """
    Select a random worker IP address from a list of workers. Its for the random-hit proxy implementation

    Args:
    workers (list): A list of worker IP addresses.

    Returns:
    str: A randomly selected worker IP address from the list.
    """
    return random.choice(workers)


def find_speed_of_workers_ms(worker_ip):
    """
    Measure the ping response time of a worker node in milliseconds.

    This function sends a ping to the specified worker node IP address and measures the 
    average round-trip time in milliseconds.

    Args:
    worker_ip (str): The IP address of the worker node.

    Returns:
    float or None: The average round-trip time in milliseconds, or None if the ping fails.
    """

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
    """
    Identify the worker node with the lowest latency.

    This function iterates over a list of worker nodes, pings each, and identifies 
    the node with the lowest average round-trip time.

    Args:
    all_workers (list): A list of worker node IP addresses.

    Returns:
    tuple: A tuple containing the IP address of the fastest worker node and its ping time.
    """

    min_avg_time = float('inf')

    for worker in all_workers:
        avg_time = find_speed_of_workers_ms(worker)
        if avg_time < min_avg_time:
            min_avg_time = avg_time
            fastest_node = worker
    return fastest_node,min_avg_time

# convert the ip address to string
def to_string_ip(ip_address):
    """
    Convert an IP address to a string format.

    Args:
    ip_address: The IP address to convert.

    Returns:
    str: The IP address in string format.
    """

    return str(ip_address)

@app.route("/")
def default():
    """
    Default route handler for the web application.

    This route returns an HTML string that lists the available proxy implementation options.

    Returns:
    str: HTML content describing the available options.
    """
    return '<h1> Select one of the above proxy implementation : 1) /direct-hit 2) /random-hit 3) /customized-hit </h1>'

@app.route('/manager')
def manager():
    """
    manager route for the web application.

    This route returns the manager IP.

    Returns:
    str: Manager IP's public ip address.
    """
    manager_ip = get_manager_ips()
    return "Manager IP: " + str(manager_ip)

@app.route('/workers')
def worker():
    """
    manager route for the web application.

    This route returns the manager IP.

    Returns:
    str: Manager IP's public ip address.
    """
    worker_ip = get_workers_ips()
    return "worker IP: " + str(worker_ip)

# ----------------- Proxy methods ------------------------------------# 
# For all the proxy patterns implementations here is an example of the url : 
# http://ADDRESS:PORT/PROXY_METHOD?query=YOURSQLQUERY;

# Direct-hit proxy : immediately send the request to the master(manager) node. 
@app.route('/direct-hit')
def direct_hit():
    """
    Handle the 'direct-hit' proxy method.

    This route processes a direct-hit request by taking an SQL query parameter,
    and sending it directly to the manager node for execution. The response from 
    the manager node is returned to the client.

    Returns:
    str: The response from executing the SQL query on the manager node.
    """
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    print(f"Proxy direct-hit \n Sending request to : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=manager_ip,sql_query=query_params)

# Random-hit proxy is randomly choosing a worker node and sending the request to that node.
@app.route('/random-hit')
def random_hit():
    """
    Handle the 'random-hit' proxy method.

    This route processes a random-hit request by taking an SQL query parameter,
    randomly selecting a worker node, and sending the query to this node. The 
    response from the worker node is returned to the client.

    Returns:
    str: The response from executing the SQL query on the randomly selected worker node.
    """
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    worker_ip = get_random_worker(get_workers_ips())
    print(f"Proxy random-hit \n Sending request to worker : {worker_ip} where manager node : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=worker_ip,sql_query=query_params)
 

# Customized-hit proxy is choosing the worker node with the lowest latency and sending the request to that worker node.
@app.route('/custom-hit')
def customized():
    """
    Handle the 'custom-hit' proxy method.

    This route processes a custom-hit request by taking an SQL query parameter,
    finding the worker node with the lowest latency, and sending the query to 
    this node. The response from the fastest worker node is returned to the client.

    Returns:
    str: The response from executing the SQL query on the fastest worker node.
    """
    query_params = request.args.get('query')
    manager_ip = to_string_ip(get_manager_ips())
    worker_ip_list = get_workers_ips()
    fastest_worker_ip,ping_time = find_fastest_worker_node(worker_ip_list)
    print(f"Proxy custom-hit \n Sending request to fastest worker : {fastest_worker_ip} with ping response time : {ping_time} where manager node : {manager_ip} with query : {query_params}")
    return ssh_connection_handler(manager_ip=manager_ip,worker_ip=fastest_worker_ip,sql_query=query_params)

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)