#!/bin/bash

. ./config.sh

set -x

##prepare manifest

cat "./templates/conjur-follower-template.yml" | \
sed -e "s#{{ K8S_FOLLOWER_REPLICA_COUNT }}#$K8S_FOLLOWER_REPLICA_COUNT#g" | \
sed -e "s#{{ K8S_FOLLOWER_APP_LABEL }}#$K8S_FOLLOWER_APP_LABEL#g" | \
sed -e "s#{{ K8S_FOLLOWER_SVC_ACCT }}#$K8S_FOLLOWER_SVC_ACCT#g" | \
sed -e "s#{{ SEED_FETCHER_REPO }}#$SEED_FETCHER_REPO#g" | \
sed -e "s#{{ DAP_HOSTNAME }}#$DAP_HOSTNAME#g" | \
sed -e "s#{{ DAP_ACCT }}#$CONJUR_ACCOUNT#g" | \
sed -e "s#{{ DAP_AUTHN_K8S_BRANCH }}#$DAP_AUTHN_K8S_BRANCH#g" | \
sed -e "s#{{ K8S_FOLLOWER_LOGIN }}#$K8S_FOLLOWER_LOGIN#g" | \
sed -e "s#{{ CONJUR_APPLIANCE_REPO }}#$DOCKER_IMAGE#g" \
> ./policy/conjur-follower.yml

read -p "\n==== Review conjur-follower.yml before moving on to the next step and press enter ====\n"


kubectl create -f ./policy/conjur-follower.yml

echo "==== Deployments ===="
kubectl get deployments
echo "==== Pods ===="
kubectl get pods

set +x

printf "\n====== Deployment of Followers into Kubernetes Complete ====="
printf "\n============================================================="
printf "\n\nNOTES:"
printf "\n- Using the pod IDs displayed above,"
printf "\n  run kubectl logs pod-id -c authenticator"
printf "\n  to determine if the authenticator correctly pulled the seed file."
printf "\n============================================================="






#rm -rf mydata/
#docker run --rm -it -v $(PWD)/mydata/:/root --entrypoint bash cyberark/conjur-cli:5 -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $CONJUR_URL"
#docker run --rm -it -v $(PWD)/mydata/:/root cyberark/conjur-cli:5 authn login -u admin -p $CONJUR_ADMIN_PASSWORD

#cp -rf policy mydata/policy
#docker run --rm -it -v $(PWD)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/kubernetes-followers.yml


#main() {
#  kubectl config set-context $(kubectl config current-context) --namespace="default" > /dev/null
#  deploy_conjur_followers
#  sleep 10
#  echo "Followers created."
#}

#deploy_conjur_followers() {
#  announce "Deploying Conjur Follower pods."
#  conjur_appliance_image=$(platform_image "conjur-appliance")
#
#  sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$CONJUR_APPLIANCE_IMAGE#g" "./kubernetes/conjur-follower.yaml" |
#    sed -e "s#{{ AUTHENTICATOR_ID }}#$AUTHENTICATOR_ID#g" |
#    sed -e "s#{{ IMAGE_PULL_POLICY }}#$IMAGE_PULL_POLICY#g" |
#    sed -e "s#{{ CONJUR_FOLLOWER_COUNT }}#${CONJUR_FOLLOWER_COUNT}#g" |
#    $cli create -f -
#}

#main $@
