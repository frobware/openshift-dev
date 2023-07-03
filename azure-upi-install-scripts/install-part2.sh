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

# We expect to find openshift-install in the current directory.
export PATH=$PWD:$PATH

# By default send SIGTERM to every process in the process group.
# Overridden once we know the approve-csr.sh pid.
approve_csr_subshell_pid=0
trap 'kill $approve_csr_subshell_pid' INT EXIT

source "$1"
export KUBECONFIG="$PWD/auth/kubeconfig"
export WORKER_IGNITION=`cat worker.ign | base64 | tr -d '\n'`

az deployment group create -g $RESOURCE_GROUP \
   --template-file "06_workers.json" \
   --parameters workerIgnition="$WORKER_IGNITION" \
   --parameters baseName="$INFRA_ID"

./check-vms-running.sh "$RESOURCE_GROUP"

(set +e; ./approve-csr.sh "$KUBECONFIG") &
approve_csr_subshell_pid=$!

max_retries=30
retry_interval=30
attempt=0

# Disable exit on error.
set +e

while true; do
    oc_output=$(oc -n openshift-ingress get service router-default --no-headers || echo "failed")
    if [[ $oc_output == "failed" ]]; then
        echo "Failed to get PUBLIC_IP_ROUTER. Retrying..."
        ((attempt++))
        if ((attempt > max_retries)); then
            echo "Failed to get PUBLIC_IP_ROUTER after $max_retries attempts. Exiting..."
            exit 1
        fi
        sleep $retry_interval
        continue
    fi
    export PUBLIC_IP_ROUTER=$(echo "$oc_output" | awk '{print $4}')
    break
done

# Re-enable exit on error.
set -e

# Add a *.apps record to the public DNS zone:
az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${BASE_DOMAIN} -n '*.apps'.${CLUSTER_NAME} -a $PUBLIC_IP_ROUTER --ttl 300

# Finally, add a *.apps record to the private DNS zone:
az network private-dns record-set a create -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n '*.apps' --ttl 300
az network private-dns record-set a add-record -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n '*.apps' -a $PUBLIC_IP_ROUTER

openshift-install wait-for install-complete --log-level debug
