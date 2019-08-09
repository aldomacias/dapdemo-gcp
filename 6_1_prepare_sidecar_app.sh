#!/bin/bash

. ./config.sh

set -x
#preparing authenticator policies to allow authentication from apps running with specific service account
APP_SERVICE_ACCOUNT=test-app-sidecar

#cat ./templates/authenticator-identities-template.yml | \
#  sed -e "s#{{ DAP_AUTHN_K8S_BRANCH }}#$DAP_AUTHN_K8S_BRANCH#g" | \
#  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_SIDECAR_NS#g" | \
# sed -e "s#{{ APPLICATION_SERVICE_ACCOUNT }}#$APP_SERVICE_ACCOUNT#g"  \
#  > ./policy/authenticator-identities.yml

cat ./templates/app-identities-sidecar-template.yml | \
  sed -e "s#{{ DAP_AUTHN_K8S_BRANCH }}#$DAP_AUTHN_K8S_BRANCH#g" \
  > ./policy/app-identities-sidecar.yml

# load policies to root

api_key=$(curl -sk --user $CONJUR_USER:$CONJUR_ADMIN_PASSWORD https://$DAP_HOSTNAME/authn/$CONJUR_ACCOUNT/login)
auth_result=$(curl -sk https://$DAP_HOSTNAME/authn/$CONJUR_ACCOUNT/$CONJUR_USER/authenticate -d "$api_key")

DAP_TOKEN=$(echo -n $auth_result | base64 | tr -d '\r\n')
DAP_AUTH_HEADER="Authorization: Token token=\"$DAP_TOKEN\""

POST_URL="https://$DAP_HOSTNAME/policies/$CONJUR_ACCOUNT/policy/root"
curl -sk -H "$DAP_AUTH_HEADER" -d "$(< ./policy/human-users.yml)" $POST_URL

POST_URL="https://$DAP_HOSTNAME/policies/$CONJUR_ACCOUNT/policy/root"
curl -sk -H "$DAP_AUTH_HEADER" -d "$(< ./policy/authenticator-identities.yml)" $POST_URL

POST_URL="https://$DAP_HOSTNAME/policies/$CONJUR_ACCOUNT/policy/root"
curl -sk -H "$DAP_AUTH_HEADER" -d "$(< ./policy/app-identities-sidecar.yml)" $POST_URL

# load postgress variables to dap
DB_USER=test_app_sidecar
DB_PASS=$(openssl rand -hex 12) # generate a random password
POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/test-app-sidecar-db/db-username"
curl -sk -H "$DAP_AUTH_HEADER" --data "$DB_USER" $POST_URL

POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/test-app-sidecar-db/url"
curl -sk -H "$DAP_AUTH_HEADER" --data "postgresql://test-app-sidecar-backend.$TEST_APP_SIDECAR_NS.svc.cluster.local:5432/postgres" $POST_URL


POST_URL="https://$DAP_HOSTNAME/secrets/$CONJUR_ACCOUNT/variable/test-app-sidecar-db/db-password"
curl -sk -H "$DAP_AUTH_HEADER" --data "$DB_PASS" $POST_URL
# send password to schema.sql to create the user with the generated password.
cat ./templates/schema-template.sql | \
  sed -e "s#{{ DB_USERNAME }}#$DB_USER#g" | \
  sed -e "s#{{ DB_PASSWORD }}#$DB_PASS#g" \
  > ./test-app/sidecar/pg/schema.sql