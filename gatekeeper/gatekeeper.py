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
    # aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')


# We want to convert from 3.94.213.44 to ec2-3-94-213-44.compute-1.amazonaws.com
def modify_ip_to_dns(trusted_host_ip):
    """
    Convert an IP address to a specific DNS format used for AWS instances.

    This function takes an IP address as input and converts it into a DNS name 
    following a specific format required for AWS EC2 instances. The IP address 
    segments separated by dots are replaced with hyphens, and a standard AWS DNS 
    prefix and suffix are added.

    Args:
    trusted_host_ip (str): The IP address of the trusted host.

    Returns:
    str: The modified DNS name corresponding to the input IP address.
    """
    aws_ip = trusted_host_ip.replace('.','-')
    return "ec2-"+aws_ip+".compute-1.amazonaws.com"

def get_trusted_host_address_to_dns():
    """
    Retrieve the DNS address of the first running trusted host in AWS EC2.

    This function queries AWS EC2 instances that are tagged as 't2_trusted_host' 
    and are in a 'running' state. It then takes the public IP address of the first 
    instance from the returned list and converts it to a DNS format using the 
    modify_ip_to_dns function.

    Returns:
    str: The DNS address of the first (and only) running trusted host.
    """
    trusted_host_list = []
    trusted_host_ips = ec2_resource.instances.filter(
        Filters=[
            {'Name': 'tag:Name', 'Values': ['t2_trusted_host']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ])
    for trusted_host in trusted_host_ips:
        trusted_host_list.append(trusted_host.public_ip_address)
    return modify_ip_to_dns(trusted_host_list[0])

# This function allows to establish a ssh tunnel and send a request to the proxy.
def ssh_handler(trusted_host_dns, proxy_type, sql_query):
    """
    Establish an SSH tunnel to a trusted host and send a request via proxy.

    This function sets up an SSH tunnel to a trusted host using its DNS address. 
    It then sends an HTTP request through this tunnel, which includes the proxy 
    type and an SQL query as parameters. The response from the trusted host is 
    captured and returned.

    Args:
    trusted_host_dns (str): The DNS address of the trusted host.
    proxy_type (str): The type of proxy to use.
    sql_query (str): The SQL query to send to the proxy.

    Returns:
    str: The response received from the trusted host.
    """

    response = "Response from trusted host: \n"

    with SSHTunnelForwarder(
        (trusted_host_dns,22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(trusted_host_dns, 80) # we will use http to send the request.
    ) as tunnel:
        try:
            dns = f'http://{trusted_host_dns}/trusted_host?proxy_type={proxy_type}&query={sql_query}'
            # send a request to the trusted host via http. The trusted host, will redirected it to the proxy.
            res = requests.get(dns) 
            # print(f'http://{trusted_host_dns}/trusted_host?proxy_type={proxy_type}&query={sql_query}')
            print(res.text)
            response = response + ' ' + str(res.text)

        except Exception as e:
            print(f"Connection to trusted host: error establishing SSH tunnel: {e}")
        finally:
            print("Connection to trusted host : Tunnel closed")
    return response

@app.route("/")
def default():
    """
    Default route for the web application.

    This route returns the DNS address of the first running trusted host in AWS EC2.
    It serves as the default entry point for the web application.

    Returns:
    str: The DNS address of the first running trusted host.
    """
    return get_trusted_host_address_to_dns()

@app.route("/online")
def online():
    """
    Check if the gatekeeper is online.

    This route confirms the online status of the gatekeeper by returning a message 
    with the DNS address of the first running trusted host in AWS EC2.

    Returns:
    str: A message indicating that the gatekeeper is online along with its DNS address.
    """
    return f"Gatekeeper online running at  {get_trusted_host_address_to_dns()}"

@app.route('/gatekeeper', methods=['GET'])
def sending_to_trusted_host():
    """
    Handle requests sent to the trusted host via the gatekeeper.

    This route captures HTTP GET requests, extracts the proxy type and SQL query 
    parameters, and forwards them to the trusted host using the ssh_handler function. 
    It returns the response received from the trusted host.

    Returns:
    str: The response from the trusted host.
    """
    proxy_type = request.args.get('proxy_type')
    params = request.args.get('query')
    trusted_host_dns = get_trusted_host_address_to_dns()
    print(f"Connection gatekeeper : Sending requests to trusted_host with proxy type : {proxy_type} at DNS: {trusted_host_dns} with params: {params}")
    return ssh_handler(trusted_host_dns=trusted_host_dns, proxy_type=proxy_type, sql_query=params)

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)