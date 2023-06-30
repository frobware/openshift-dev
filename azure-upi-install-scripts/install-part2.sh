#!/usr/bin/env bash

set -eux

if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide an environment file."
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "The provided argument is not a file or doesn't exist. Please provide a valid file."
    exit 1
fi

source "$1"
export KUBECONFIG="$PWD/auth/kubeconfig"
export WORKER_IGNITION=`cat worker.ign | base64 | tr -d '\n'`

az deployment group create -g $RESOURCE_GROUP \
   --template-file "06_workers.json" \
   --parameters workerIgnition="$WORKER_IGNITION" \
   --parameters baseName="$INFRA_ID"

./check-vms-running.sh "$RESOURCE_GROUP"

(set +e; ./approve-csr.sh "$KUBECONFIG") &

# Add a *.apps record to the public DNS zone:
#
# export PUBLIC_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`
# az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n *.apps -a $PUBLIC_IP_ROUTER --ttl 300

# Or, in case of adding this cluster to an already existing public zone, use instead:
#
export PUBLIC_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`
az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${BASE_DOMAIN} -n '*.apps'.${CLUSTER_NAME} -a $PUBLIC_IP_ROUTER --ttl 300

# Finally, add a *.apps record to the private DNS zone:
export PUBLIC_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`
az network private-dns record-set a create -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n '*.apps' --ttl 300
az network private-dns record-set a add-record -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n '*.apps' -a $PUBLIC_IP_ROUTER

openshift-install wait-for install-complete --log-level debug
