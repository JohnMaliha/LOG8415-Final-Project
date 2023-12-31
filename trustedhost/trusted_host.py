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
def modify_ip_to_dns(proxy_ip):
    """
    Convert an IP address to a DNS format suitable for AWS EC2 instances.

    This function transforms a given IP address into a DNS name by replacing dots 
    with hyphens and appending an AWS-specific prefix and suffix.

    Args:
    proxy_ip (str): The IP address of the proxy.

    Returns:
    str: The DNS name corresponding to the given IP address.
    """
    aws_ip = proxy_ip.replace('.','-')
    return "ec2-"+aws_ip+".compute-1.amazonaws.com"

def get_proxy_address_to_dns():
    """
    Retrieve the DNS address of the first running AWS EC2 instance tagged as a proxy.

    This function filters AWS EC2 instances with the tag 't2_proxy' and in a 'running' state,
    then converts the public IP address of the first instance to a DNS format using the
    modify_ip_to_dns function.

    Returns:
    str: The DNS address of the first running proxy instance.
    """
    proxy_list = []
    proxy_ips = ec2_resource.instances.filter(
        Filters=[
            {'Name': 'tag:Name', 'Values': ['t2_proxy']},
            {'Name': 'instance-state-name', 'Values': ['running']} # the running instances are the ones that interest us.
        ])
    for proxy in proxy_ips:
        proxy_list.append(proxy.public_ip_address)
    return modify_ip_to_dns(proxy_list[0])


# Function that handles the creation of the tunnel and sending the requests to the proxy.
def ssh_handler(proxy_dns, proxy_type, sql_query):
    """
    Establish an SSH tunnel to a proxy and send an HTTP request.

    This function sets up an SSH tunnel to a specified proxy using its DNS address.
    It sends an HTTP request to the proxy with specified type and SQL query parameters.
    The response from the proxy is captured and returned.

    Args:
    proxy_dns (str): The DNS address of the proxy.
    proxy_type (str): The type of proxy to use.
    sql_query (str): The SQL query to send to the proxy.

    Returns:
    str: The response received from the proxy.
    """

    response = "Response from proxy: \n"

    with SSHTunnelForwarder(
        (proxy_dns,22),
        ssh_username='ubuntu',
        ssh_pkey='final_assignment.pem',
        remote_bind_address=(proxy_dns, 5050)
    ) as tunnel:
        # Its recommended to use the dns and not the ip address. Both ways work, i decided to opt out for the dns way.
        # https://stackoverflow.com/questions/57579359/use-python-sshtunnel-for-port-forwarding-rest-request
        try:
            dns = f'http://{proxy_dns}/{proxy_type}?query={sql_query}'
            res = requests.get(dns)
            print(res.text)
            response = response + ' ' + str(res.text)

        except Exception as e:
            print(f"Connection to proxy: error establishing SSH tunnel: {e}")
        finally:
            print("Connection to proxy : Tunnel closed")
    return response

# default route for the proxy. To see it it works.
@app.route("/")
def default():
    """
    Default route handler for the proxy application.

    This route returns the DNS address of the first running proxy in AWS EC2.
    It serves as the default entry point for the proxy application.

    Returns:
    str: The DNS address of the first running proxy instance.
    """
    return get_proxy_address_to_dns()

# The route that will be used to send requests.
@app.route('/trusted_host', methods=['GET'])
def sending_to_proxy():
    """
    Handle requests sent to the proxy via the trusted host.

    This route captures HTTP GET requests, extracts the proxy type and SQL query 
    parameters, and forwards them to the proxy using the ssh_handler function.
    It returns the response received from the proxy.

    Returns:
    str: The response generated from the proxy.
    """
    proxy_type = request.args.get('proxy_type')
    params = request.args.get('query')
    proxy_dns = get_proxy_address_to_dns()
    print(f"Connection trusted-host : Sending requests to proxy: {proxy_type} at DNS: {proxy_dns} with params: {params}")
    return ssh_handler(proxy_dns=proxy_dns, proxy_type=proxy_type, sql_query=params)

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)