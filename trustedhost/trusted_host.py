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





@app.route("/")
def default():
    return '<h1> Trusted host. </h1>'



if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5000)