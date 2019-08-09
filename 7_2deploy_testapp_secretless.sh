#!/bin/bash

. ./config.sh

set -x

### TEST APP with SECRETLESS broker

echo "Creating Test App namespace."

if ! kubectl get namespace $TEST_APP_SECRETLESS_NS > /dev/null
then
    kubectl create namespace $TEST_APP_SECRETLESS_NS
fi

kubectl config set-context $(kubectl config current-context) --namespace=$TEST_APP_SECRETLESS_NS

echo "Adding Role Binding for conjur service account"

kubectl delete --ignore-not-found rolebinding test-app-secretless-authenticator-role-binding-$K8S_FOLLOWER_NS

sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_SECRETLESS_NS#g" ./test-app/secretless/test-app-conjur-authenticator-role-binding.yml |
  sed -e "s#{{ CONJUR_NAMESPACE_NAME }}#$K8S_FOLLOWER_NS#g" |
  kubectl create -f -


echo "Storing non-secret conjur cert as test app configuration data"

kubectl delete --ignore-not-found=true configmap conjur-cert

# Store the Conjur cert in a ConfigMap.
kubectl create configmap conjur-cert --from-file=ssl-certificate=./conjur-cert.pem

echo "Conjur cert stored."

echo "Storing secretless configuration in a config map"
kubectl create configmap secretless-config --from-file=./test-app/secretless/secretless.yml


echo "Pushing postgres image to google registry"

pushd test-app/secretless/pg
    docker build -t test-app-pg:$DAP_AUTHN_K8S_BRANCH .
    test_app_pg_image=$DOCKER_REGISTRY_PATH/test-app-pg-secretless
    docker tag test-app-pg:$DAP_AUTHN_K8S_BRANCH $test_app_pg_image
    docker push $test_app_pg_image
popd

echo "Deploying test app Backend"

sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_image#g" ./test-app/secretless/pg/postgres.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_SECRETLESS_NS#g" |
  kubectl create -f -

#echo "Building test app front end image"

#pushd test-app/secretless
#    docker build -t test-app-secretless:$DAP_AUTHN_K8S_BRANCH -f Dockerfile .
#    test_app_image=$DOCKER_REGISTRY_PATH/test-app-secretless
#    docker tag test-app-secretless:$DAP_AUTHN_K8S_BRANCH $test_app_image
#    docker push $test_app_image
#popd

echo "Deploying test app FrontEnd"

conjur_authenticator_url=$CONJUR_URL/authn-k8s/$DAP_AUTHN_K8S_BRANCH
follower_authenticator_url="$K8S_FOLLOWER_URL/authn-k8s/$DAP_AUTHN_K8S_BRANCH"

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_image#g" ./test-app/secretless/test-app-secretless.yml |
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
  sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$K8S_FOLLOWER_URL#g" |
  sed -e "s#{{ CONJUR_AUTHN_URL }}#$follower_authenticator_url#g" |
  sed -e "s#{{ DAP_AUTHN_K8S_BRANCH }}#$DAP_AUTHN_K8S_BRANCH#g" |
  sed -e "s#{{ TEST_APP_SECRETLESS_NS }}#$TEST_APP_SECRETLESS_NS#g" |
  kubectl create -f -


echo "Waiting for services to become available"
while [ -z "$(kubectl describe service test-app-secretless | grep 'LoadBalancer Ingress' | awk '{ print $3 }')" ]; do
    printf "."
    sleep 1
done

kubectl describe service test-app-secretless | grep 'LoadBalancer Ingress'

app_url=$(kubectl describe service test-app-secretless | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

echo -e "Adding entry to the secretless app\n"
curl  -d '{"name": "Mr. Secretless"}' -H "Content-Type: application/json" $app_url/pet
