#!/bin/bash

. ./config.sh

set -x

### SOLO EJECUTAR SI SE QUIERE DESPLEGAR LA APP DE PRUEBA PETS
## valida si existe el namespace de la app y si no lo crea

echo "Creating Test App namespace."

if ! kubectl get namespace $TEST_APP_NS > /dev/null
then
    kubectl create namespace $TEST_APP_NS
fi

kubectl config set-context $(kubectl config current-context) --namespace=$TEST_APP_NS

echo "Pushing postgres image to google registry"

pushd test-app/normal/pg
    docker build -t test-app-pg:$DAP_AUTHN_K8S_BRANCH .
    test_app_pg_image="$DOCKER_REGISTRY_PATH/test-app-pg"
    docker tag test-app-pg:$DAP_AUTHN_K8S_BRANCH $test_app_pg_image
    docker push $test_app_pg_image
popd

echo "Deploying test app Backend"

sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_image#g" ./test-app/normal/pg/postgres.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NS#g" |
  kubectl create -f -

echo "Building test app front end image"

pushd test-app/normal
    docker build -t test-app:$DAP_AUTHN_K8S_BRANCH -f Dockerfile .
    test_app_image="$DOCKER_REGISTRY_PATH/test-app-front"
    docker tag test-app:$DAP_AUTHN_K8S_BRANCH $test_app_image
    docker push $test_app_image
popd

echo "Deploying test app FrontEnd"

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_image#g" ./test-app/normal/test-app.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NS#g" |
    kubectl create -f -

echo "Waiting for services to become available"
while [ -z "$(kubectl describe service test-app | grep 'LoadBalancer Ingress' | awk '{ print $3 }')" ]; do
    printf "."
    sleep 1
done

kubectl describe service test-app | grep 'LoadBalancer Ingress'

app_url=$(kubectl describe service test-app | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

echo -e "Adding entry to the app\n"
curl  -d '{"name": "Insecure App"}' -H "Content-Type: application/json" $app_url/pet
