# For more details on the required environment
# variables, please see the README

# Make sure you comment out the section for the
# platform you're not using, and fill in the
# appropriate values for each env var

ZONE=us-central1-a
CLUSTER=demo-dap-cluster
PROJECT=conjur-k8s-demo-230517

K8S_FOLLOWER_REPLICA_COUNT="1"
K8S_FOLLOWER_SVC_ACCT="conjur-cluster"
K8S_FOLLOWER_APP_LABEL="conjur-follower"
K8S_FOLLOWER_NS="conjur-dev"
K8S_FOLLOWER_URL="https://$K8S_FOLLOWER_APP_LABEL.$K8S_FOLLOWER_NS.svc.cluster.local"
DAP_AUTHN_K8S_BRANCH=gke-dev    #authenticator-id
K8S_FOLLOWER_LOGIN="host/conjur/authn-k8s/$DAP_AUTHN_K8S_BRANCH/apps/$K8S_FOLLOWER_NS/service_account/$K8S_FOLLOWER_SVC_ACCT"


CONJUR_VERSION=10.10
CONJUR_APPLIANCE_IMAGE="conjur-appliance:$CONJUR_VERSION"
CONJUR_APPLIANCE_TARFILE=/Users/mer/LocalDocuments/CyberArk/conjur-appliance-10.10.tar
DOCKER_REGISTRY_PATH=gcr.io/conjur-k8s-demo-230517
SEED_FETCHER_REPO="$DOCKER_REGISTRY_PATH/seed-fetcher:$K8S_FOLLOWER_NS"

CONJUR_ACCOUNT=demo
CONJUR_USER=admin
CONJUR_ADMIN_PASSWORD=Cyberark1
DAP_HOSTNAME=dap.demo.conjur.com
CONJUR_URL="https://"$DAP_HOSTNAME":443"
INSTANCE_NAME=dap-master
DOCKER_IMAGE="$DOCKER_REGISTRY_PATH/$CONJUR_APPLIANCE_IMAGE"

TEST_APP_NS=test-app
TEST_APP_SIDECAR_NS=test-app-sidecar
TEST_APP_SECRETLESS_NS=test-app-secretless

AUTHENTICATOR_CLIENT_IMAGE=cyberark/conjur-kubernetes-authenticator
#######
# KUBERNETES CONFIG (uncomment all lines if using this configuration)
#######
#export PLATFORM=kubernetes
#export DOCKER_REGISTRY_URL=gcr.io
