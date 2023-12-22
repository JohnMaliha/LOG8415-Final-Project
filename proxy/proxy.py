import random
import boto3
import os

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

all_workers_ip = str(get_workers_ips())

manager_ip = get_workers_ips()

# Create an ssh tunnel
def initiate_ssh_connection(manager,worker,content):
    manager_ip = str(manager)
    tunnel = SSHTunnelForwarder(
        (manager_ip, 22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(manager_ip, 3306),
        local_bind_address=('localhost', 9000)
    )
    tunnel.start()

    try:
        # Establish the SSH tunnel
        tunnel = initiate_ssh_connection(manager_ip,worker,content)
        print(f"Tunnel established to {manager_ip} Local port: {3306}")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        if tunnel:
            tunnel.stop()
            print("Tunnel closed")

    return tunnel


def send_requests():
    # TO DO
    return 


# Returns a random worker for random hit
def get_random_worker(workers):
    return random.choice(workers)


def find_speed_of_workers_ms(worker_ip,):
    try:
        response = ping(worker_ip, count=1, timeout=1)
        if response.success():
            # Calculate the average round-trip time
            avg_time_ms = response.rtt_avg_ms
            return avg_time_ms
        else:
            return None
    except Exception as e:
        print(f"No response was returned: {e}")
        return None


@app.route("/")
def default():
    return 'Default'

@app.route('/manager')
def manager():
    manager_ip = get_manager_ips()
    return "Manager IP: " + str(manager_ip)

@app.route('/workers')
def worker():
    worker_ip = get_workers_ips()
    return "worker IP: " + str(worker_ip)

@app.route('/direct-hit')
def direct_hit():
    return initiate_ssh_connection(manager=manager_ip,worker=str(all_workers_ip[0]),content="ff")


@app.route('/random-hit')
def random_hit():
    return get_random_worker(all_workers_ip)
 

@app.route('/custom-hit')
def customized():
    return






if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)