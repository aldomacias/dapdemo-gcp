#!/bin/bash
. ./config.sh
set -x

gcloud container clusters create "$CLUSTER" --zone "$ZONE"
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
