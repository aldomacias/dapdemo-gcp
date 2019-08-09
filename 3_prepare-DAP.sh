#!/usr/bin/env bash

. ./config.sh

set -x 
## prepare root policy
cat "./templates/root-template.yml" | \
  sed -e "s#{{ K8S_FOLLOWER_NS }}#$K8S_FOLLOWER_NS#g"  | \
  sed -e "s#{{ K8S_FOLLOWER_SVC_ACCT }}#$K8S_FOLLOWER_SVC_ACCT#g"  | \
  sed -e "s#{{ DAP_AUTHN_K8S_BRANCH }}#$DAP_AUTHN_K8S_BRANCH#g" \
  > ./policy/root.yml

read -p "\n==== Review root.yml before moving on to the next step and press enter to continue ====\n"

## loading policy and k8s connection details
VALUE_FILE=./k8s_values.json

api_key=$(curl -sk --user $CONJUR_USER:$CONJUR_ADMIN_PASSWORD https://$DAP_HOSTNAME/authn/$CONJUR_ACCOUNT/login)
auth_result=$(curl -sk https://$DAP_HOSTNAME/authn/$CONJUR_ACCOUNT/$CONJUR_USER/authenticate -d "$api_key")

DAP_TOKEN=$(echo -n $auth_result | base64 | tr -d '\r\n')
DAP_AUTH_HEADER="Authorization: Token token=\"$DAP_TOKEN\""

POST_URL="https://$DAP_HOSTNAME/policies/$CONJUR_ACCOUNT/policy/root"
curl -sk -H "$DAP_AUTH_HEADER" -d "$(< ./policy/root.yml)" $POST_URL

POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/conjur/authn-k8s/$DAP_AUTHN_K8S_BRANCH/kubernetes/service-account-token"
SVC_ACCT_TOKEN=$(cat $VALUE_FILE | jq -r .svc_token | base64 -D)
curl -sk -H "$DAP_AUTH_HEADER" --data "$SVC_ACCT_TOKEN" $POST_URL

POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/conjur/authn-k8s/$DAP_AUTHN_K8S_BRANCH/kubernetes/ca-cert"
CA_CERT=$(cat $VALUE_FILE | jq -r .ca_cert | base64 -D)
curl -sk -H "$DAP_AUTH_HEADER" --data "$CA_CERT" $POST_URL

POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/conjur/authn-k8s/$DAP_AUTHN_K8S_BRANCH/kubernetes/api-url"
API_URL=$(cat $VALUE_FILE | jq -r .api_url)
curl -sk -H "$DAP_AUTH_HEADER" --data "$API_URL" $POST_URL

##initialize CA in DAP

gcloud compute ssh $INSTANCE_NAME \
    --command  "sudo docker exec dap-master chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init[""conjur/authn-k8s/$DAP_AUTHN_K8S_BRANCH""]"

## enable authenticator
gcloud compute ssh $INSTANCE_NAME \
    --command  "sudo docker exec dap-master bash -c 'echo CONJUR_AUTHENTICATORS=""authn,authn-k8s/$DAP_AUTHN_K8S_BRANCH"" >> /opt/conjur/etc/conjur.conf && sv restart conjur'"

sleep 15

echo "==== Enabled DAP Authenticators ===="
curl -sk https://$DAP_HOSTNAME/info | jq '.authenticators.enabled'
