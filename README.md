# Final projet : LOG8415

## To start the application and create the ec2 instances and the load balancer.
- 1) cd scripts
- 2) In windows : bash run_instances.sh
- 3) In linux : ./run_instances.sh

## Requests
- 1) cd scripts
- 2) In windows : bash run_requests.sh
- 3) In linux : ./run_requests.sh

## Destroy ec2 instances and load balancer.
- 1) cd scripts 
- 2) In windows : bash nuke_terraform.sh
- 3) In linux : ./nuke_terraform.sh

## Create, run, and uplad the docker image manually.
- 1) docker build -t APP_NAME .
- 2) docker run -p 5000:5000 APP_NAME
- 3) docker tag APP_NAME therealflash/final_projet_XXXX
- 4) docker push therealflash/final_projet_XXXX

## Create ec2 instances and load balancer manually.
- 1) terraform init
- 2) terraform plan
- 3) terraform apply
  4) Or, use the terraform_create.sh bash in cd final_projet/scripts.

## To see logs on the server 
- cat /var/log/cloud-init-output.log
