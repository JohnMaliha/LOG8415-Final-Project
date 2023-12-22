from flask import Flask, request
import boto3
import os
import json
from sshtunnel import SSHTunnelForwarder
import MySQLdb

from credentials import * 

app = Flask(__name__)
app.debug =True

PROXY_URL = '100.26.174.95'

session = boto3.Session(
    aws_access_key_id = access_key,
    aws_secret_access_key = secret_key,
    aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')

# Getting dynamically the ips for the workers and manager.
# get workersIPS: 
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
    all_workers = ec2_resource.instances.filter(Filters=[
        {'Name': 'tag:Name', 'Values': ['t2_mysql_cluster_worker1','t2_mysql_cluster_worker2','t2_mysql_cluster_worker3']},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ])
    for worker in all_workers:
        worker_list.append(worker.public_ip_address)
    return worker_list

def get_manager_node_public_ip(instance_id):
    instance = ec2_resource.Instance(instance_id)
    return instance.public_ip_address

worker = get_workers_ips()

manager = get_workers_ips()[0]

# Create an ssh tunnel
def create_ssh_tunnel():

    tunnel = SSHTunnelForwarder(
        (get_manager_ips(), 22),
        ssh_username='ubuntu',
        ssh_pkey= 'LOG8415-Final-Project/proxy/final_assignment.pem',
        remote_bind_address=(worker, 3306) # worker TO DO FOR ALL THREE
        local_bind_address= ('localhost', 9000)
    )
    tunnel.start()

    try:
        # Establish the SSH tunnel
        tunnel = create_ssh_tunnel()
        print(f"Tunnel established. Local port: {tunnel.local_bind_port}")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        if tunnel:
            tunnel.stop()
            print("Tunnel closed")

    return tunnel
    
# logic for a direct hit.
def direct_hit():
    # TO DO
    return 

def random_hit():
    #TO DO
    return

def customized_hit():
    #TO DO
    return








@app.route("/")
def default():
    return 'Default'

@app.route('/manager')
def manager():
    manager_ip = get_manager_ips()
    return "Manager IP: " + str(manager_ip)


@app.route('/worker')
def worker():
    worker_ip = get_workers_ips()
    return "worker IP: " + str(worker_ip)

@app.route('/direct')
def direct_hit():
      answer = direct_hit()

# @app.route('/random-hit')
# def random():
#     return 

# @app.route('/custom-hit')
# def customized():
#     return






if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)