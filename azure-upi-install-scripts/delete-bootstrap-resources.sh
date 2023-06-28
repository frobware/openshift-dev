#!/usr/bin/env bash

set -eu

if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide an environment file."
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "The provided argument is not a file or doesn't exist. Please provide a valid file."
    exit 1
fi

source "$1"
export PATH=$PWD:$PATH

az network nsg rule delete -g $RESOURCE_GROUP --nsg-name ${INFRA_ID}-nsg --name bootstrap_ssh_in
az vm stop -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm deallocate -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap --yes
az disk delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap_OSDisk --no-wait --yes
az network nic delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-nic --no-wait
az storage blob delete --account-key $ACCOUNT_KEY --account-name ${CLUSTER_NAME}sa --container-name files --name bootstrap.ign
az network public-ip delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-ssh-pip
