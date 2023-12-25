import time
import requests 
import threading
import boto3

from credentials import *

stop_requests = threading.Event() # global event to detect keyboard interrupt.

session = boto3.Session(
    aws_access_key_id = access_key,
    aws_secret_access_key = secret_key,
    aws_session_token = token,
    region_name= "us-east-1"
)
ec2_resource = session.resource('ec2')

# get the load balancer DNS 
def get_gatekeeper_dns():
    gatekeeper = list(ec2_resource.instances.filter(Filters=[
        {'Name': 'tag:Name', 'Values': ['t2_gatekeeper']},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ]))

    ip = gatekeeper[0].public_ip_address
    dns = "http://" + ip + "/gatekeeper"

    return  dns

def getRequestSync(gatekeeper_dns):
    res = requests.get(gatekeeper_dns)
    print(res.json())


def send_requests(gatekeeper_dns, request_count): 
    for _ in range(request_count):
        if stop_requests.is_set():
            break
        getRequestSync(gatekeeper_dns)

def run_threads_requests(thread_count, request_count, orchestratorDns):
    for _ in range(thread_count):
        thread = threading.Thread(target=send_requests,args=(orchestratorDns, request_count))
        thread.daemon = True
        thread.start()

run_threads_requests(
    thread_count=100,
    request_count=1,
    gatekeeperDns=get_gatekeeper_dns()
)

# If we need to stop the threads for some reason we can use ctrl + c. 
try :
    while True:
        time.sleep(1)

except KeyboardInterrupt:
    stop_requests.set()
    print("'\n' KeyboardInterrupt has been caught.")