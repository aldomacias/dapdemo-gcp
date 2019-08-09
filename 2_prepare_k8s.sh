#!/bin/bash
set -x

. ./config.sh

set -x

sed -e "s#{{ K8S_FOLLOWER_NS }}#$K8S_FOLLOWER_NS#g" "./templates/conjur-k8s-role-template.yml" | \
sed -e "s#{{ K8S_FOLLOWER_SVC_ACCT }}#$K8S_FOLLOWER_SVC_ACCT#g"  | \
sed -e "s#{{ K8S_FOLLOWER_APP_LABEL }}#$K8S_FOLLOWER_APP_LABEL#g" \
> ./policy/conjur-role.yml 

kubectl create -f ./policy/conjur-role.yml

kubectl config set-context $(kubectl config current-context) --namespace=$K8S_FOLLOWER_NS

echo -n | openssl s_client \
    -showcerts \
    -connect $DAP_HOSTNAME:443 \
    | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
    > ./conjur-cert.pem

kubectl create configmap server-certificate \
    --from-file=ssl-certificate=./conjur-cert.pem

## getting information from k8s to store in dap master
TOKEN_SECRET_NAME="$(kubectl get secrets -n $K8S_FOLLOWER_NS \
    | grep 'conjur.*service-account-token' \
    | head -n1 \
    | awk '{print $1}')"

K8S_CA_CERT="$(kubectl get secret -n $K8S_FOLLOWER_NS $TOKEN_SECRET_NAME -o json \
      | jq -r '.data["ca.crt"]')"

K8S_SVC_ACCT_TOKEN="$(kubectl get secret -n $K8S_FOLLOWER_NS $TOKEN_SECRET_NAME -o json \
      | jq -r .data.token)"

K8S_API_URL="$(kubectl config view --minify -o json \
      | jq -r '.clusters[0].cluster.server')"

cat << EOF > ./k8s_values.json
{
  "ca_cert": "$K8S_CA_CERT",
  "svc_token": "$K8S_SVC_ACCT_TOKEN",
  "api_url": "$K8S_API_URL"
}
EOF

printf "\n\n==== Done collecting information. Information stored in ../k8s_values.json ====\n"
printf "==== Please provide the ../k8s_values.json values to the DAP Administrator ====\n\n"
