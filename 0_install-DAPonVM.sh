#!/bin/bash
. ./config.sh
set -x

gcloud compute firewall-rules delete allow-dap-ports --quiet
gcloud compute instances delete $INSTANCE_NAME --quiet

gcloud compute instances create-with-container $INSTANCE_NAME \
     --container-image $DOCKER_IMAGE \
     --project=$PROJECT \
     --zone=$ZONE \
     --tags=dap-server 

gcloud compute firewall-rules create allow-dap-ports \
    --allow tcp:443,tcp:636,tcp:5432,tcp:1999 --target-tags dap-server
sleep 30s

# delete the running container as it does not start well
gcloud compute ssh $INSTANCE_NAME \
    --command 'sudo docker rm -f $(docker ps -f name=dap -q)'

## ssh to VM 
gcloud compute ssh $INSTANCE_NAME \
    --command "sudo docker run --name dap-master -d --restart=always --security-opt seccomp:unconfined -p '443:443' -p '636:636' -p '5432:5432' -p '1999:1999' $DOCKER_IMAGE"
gcloud compute ssh $INSTANCE_NAME \
    --command "sudo docker exec dap-master evoke configure master --hostname $DAP_HOSTNAME --admin-password $CONJUR_ADMIN_PASSWORD $CONJUR_ACCOUNT"



# delete previous entry in google dns if exists
OLDPRIVATE_IP=$(gcloud dns --project=$PROJECT record-sets list --name=$DAP_HOSTNAME --type=A --zone=conjur-demos | grep $DAP_HOSTNAME | awk '{print $4}')
if [[ "$OLDPRIVATE_IP" != "" ]];
then
    gcloud dns --project=$PROJECT record-sets transaction start --zone=conjur-demos
    gcloud dns --project=$PROJECT record-sets transaction remove --name=$DAP_HOSTNAME --ttl=300 --type=A --zone=conjur-demos $OLDPRIVATE_IP
    gcloud dns --project=$PROJECT record-sets transaction execute --zone=conjur-demos
fi

#get the private IP of the instance
PRIVATE_IP=$(gcloud compute instances describe dap-master | grep networkIP | awk '{print $2}')
#add the IP to the DNS in google so followers can reach it
gcloud dns --project=$PROJECT record-sets transaction start --zone=conjur-demos
gcloud dns --project=$PROJECT record-sets transaction add $PRIVATE_IP --name=$DAP_HOSTNAME --ttl=300 --type=A --zone=conjur-demos
gcloud dns --project=$PROJECT record-sets transaction execute --zone=conjur-demos

#delete previous entries from /etc/hosts
sudo sed -i "" "/$DAP_HOSTNAME/d" /etc/hosts
#add a dap-hostname to local /etc/hosts
PUBLIC_IP=$(gcloud compute instances describe dap-master | grep natIP | awk '{print $2}')
echo "$PUBLIC_IP $DAP_HOSTNAME" | sudo tee -a /etc/hosts

#ssh to the container
#gcloud compute ssh $INSTANCE_NAME --container [CONTAINER_NAME]

#gcloud compute instances describe $INSTANCE_NAME



