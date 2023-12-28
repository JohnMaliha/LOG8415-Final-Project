# Final projet : LOG8415

## Setting up the environnement!
- Create credentials.py files in those folders: gatekeeper, proxy, trusted host and request.
- Create a file named : terraform.tfvars in the terrafrom folder.
- Both files have this structure : 
-- access_key = ""
-- secret_key = ""
-- token = "" 

## To start the application and create the ec2 instances.
- 1) cd scripts
- 2) In windows : bash run_projet.sh
- 3) In linux : ./run_projet.sh

## Requests
- 1) cd scripts
- 2) In windows : bash run_requests.sh
- 3) In linux : ./run_requests.sh

## Destroy ec2 instances.
- 1) cd scripts 
- 2) In windows : bash nuke_terraform.sh
- 3) In linux : ./nuke_terraform.sh

## Create, run, and uplad the docker image manually.
- 1) docker build -t APP_NAME .
- 2) docker run -p 5000:5000 APP_NAME
- 3) docker tag APP_NAME therealflash/final_projet_XXXX
- 4) docker push therealflash/final_projet_XXXX

## Create ec2 instances manually.
- 1) terraform init
- 2) terraform plan
- 3) terraform apply
  4) Or, use the terraform_create.sh bash in cd /scripts.

## In the /scripts folder
- There is scripts to create instances
- delete instances
- create all the dockers images and push them to docker hub.
- 1 main script that does everything

## To see logs on the server (instances)
- cat /var/log/cloud-init-output.log
- tail -f logs.log

## here are some examples of queries to run.
- http://GATEKEEPER_PUBLIC_IP/gatekeeper?proxy_type=custom-hit&query=SELECT%20COUNT(*)%20FROM%20film; --> shoud return 1000
- http://GATEKEEPER_PUBLIC_IP/gatekeeper?proxy_type=custom-hit&query=INSERT INTO sakila.actor (first_name, last_name) VALUES ('Homer', 'Flinstone'); --> returns nothing
- http://GATEKEEPER_PUBLIC_IP/gatekeeper?proxy_type=custom-hit&query=SELECT first_name,last_name FROM actor --> will return all the data in the table actor including homer Flinstone.

