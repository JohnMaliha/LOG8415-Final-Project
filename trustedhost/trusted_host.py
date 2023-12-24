import boto3

from flask import Flask, request
from sshtunnel import SSHTunnelForwarder
import requests

from credentials import * 

app = Flask(__name__)
app.debug =False # for debugging


session = boto3.Session(
    aws_access_key_id = access_key,
    aws_secret_access_key = secret_key,
    aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')


# We want to convert from 3.94.213.44 to ec2-3-94-213-44.compute-1.amazonaws.com
def modify_ip_to_dns(proxy_ip):
    aws_ip = proxy_ip.replace('.','-')
    return "ec2-"+aws_ip+".compute-1.amazonaws.com"

def get_proxy_address_to_dns():
    proxy_list = []
    proxy_ips = ec2_resource.instances.filter(
        Filters=[
            {'Name': 'tag:Name', 'Values': ['t2_proxy']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ])
    for proxy in proxy_ips:
        proxy_list.append(proxy.public_ip_address)
    return modify_ip_to_dns(proxy_list[0])

def ssh_handler(proxy_dns, proxy_type, sql_query):
    response = "Response from proxy: \n"

    with SSHTunnelForwarder(
        (proxy_dns,22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(proxy_dns, 5050)
    ) as tunnel:
        try:
            res = requests.get(f'http://{proxy_dns}/{proxy_type}?query={sql_query}')
            print(res.text)
            response = response + ' ' + str(res.text)

        except Exception as e:
            print(f"Connection to proxy: error establishing SSH tunnel: {e}")
        finally:
            print("Connection to proxy : Tunnel closed")
    return response

@app.route("/")
def default():
    return get_proxy_address_to_dns()

@app.route('/trusted_host', methods=['GET'])
def sending_to_proxy():
    proxy_type = request.args.get('proxy_type')
    params = request.args.get('query')
    proxy_dns = get_proxy_address_to_dns()
    print(f"Connection trusted-host : Sending requests to proxy: {proxy_type} at DNS: {proxy_dns} with params: {params}")
    return ssh_handler(proxy_dns=proxy_dns, proxy_type=proxy_type, sql_query=params)

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)