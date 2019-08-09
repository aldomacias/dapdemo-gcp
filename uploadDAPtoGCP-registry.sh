#!/bin/bash
. ./config.sh
set -x
if [[ ("$CONJUR_APPLIANCE_TARFILE" == "") 
      || ("$CONJUR_APPLIANCE_IMAGE" == "") ]]; then
	echo "source bootstrap.env to set all environment variables."
	exit -1
fi
docker load -i $CONJUR_APPLIANCE_TARFILE
IMAGE_ID=$(docker images | grep conjur-appliance | awk 'NR==1{print $3}')
docker tag $IMAGE_ID $CONJUR_APPLIANCE_IMAGE

announce "Tagging and pushing Conjur appliance"

docker tag $CONJUR_APPLIANCE_IMAGE "$DOCKER_REGISTRY_PATH/$CONJUR_APPLIANCE_IMAGE"
docker push "$DOCKER_REGISTRY_PATH/$CONJUR_APPLIANCE_IMAGE"

#push seed-fetcher to gcp registry
pushd seed-fetcher
CONJUR_NAMESPACE_NAME=latest ./build.sh
popd

docker tag seed-fetcher:latest $SEED_FETCHER_REPO
docker push $SEED_FETCHER_REPO