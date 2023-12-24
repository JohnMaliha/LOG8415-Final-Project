import boto3

from flask import Flask, request
from sshtunnel import SSHTunnelForwarder
import requests

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


# We want to convert from 3.94.213.44 to ec2-3-94-213-44.compute-1.amazonaws.com
def modify_ip_to_dns(trusted_host_ip):
    aws_ip = trusted_host_ip.replace('.','-')
    return "ec2-"+aws_ip+".compute-1.amazonaws.com"

def get_trusted_host_address_to_dns():
    trusted_host_list = []
    trusted_host_ips = ec2_resource.instances.filter(
        Filters=[
            {'Name': 'tag:Name', 'Values': ['t2_trusted_host']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ])
    for trusted_host in trusted_host_ips:
        trusted_host_list.append(trusted_host.public_ip_address)
    return modify_ip_to_dns(trusted_host_list[0])

def ssh_handler(trusted_host_dns, proxy_type, sql_query):
    response = "Response from trusted host: \n"

    with SSHTunnelForwarder(
        (trusted_host_dns,22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(trusted_host_dns, 80)
    ) as tunnel:
        try:
            res = requests.get(f'http://{trusted_host_dns}/trusted_host?proxy_type={proxy_type}&query={sql_query}')
            print(f'http://{trusted_host_dns}/trusted_host?proxy_type={proxy_type}&query={sql_query}')
            print(res.text)
            response = response + ' ' + str(res.text)

        except Exception as e:
            print(f"Connection to trusted host: error establishing SSH tunnel: {e}")
        finally:
            print("Connection to trusted host : Tunnel closed")
    return response

@app.route("/")
def default():
    return get_trusted_host_address_to_dns()

@app.route('/gatekeeper', methods=['GET'])
def sending_to_proxy():
    proxy_type = request.args.get('proxy_type')
    params = request.args.get('query')
    trusted_host_dns = get_trusted_host_address_to_dns()
    print(f"Connection gatekeeper : Sending requests to trusted_host with proxy type : {proxy_type} at DNS: {trusted_host_dns} with params: {params}")
    return ssh_handler(trusted_host_dns=trusted_host_dns, proxy_type=proxy_type, sql_query=params)

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)