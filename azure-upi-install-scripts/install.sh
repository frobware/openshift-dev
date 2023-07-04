#!/usr/bin/env bash

# This script follows the steps outlined in this document:
#   https://github.com/openshift/installer/blob/master/docs/user/azure/install_upi.md

# Avoiding Nix, Brew, et al.
if [[ "$(uname -s)" == "Darwin" ]]; then
    PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
fi

# We expect to find openshift-install(1) (and optionally oc(1)) in the
# current directory.
export PATH=$PWD:$PATH

if ! [[ -f install-config.yaml ]]; then
    echo "error: install-config.yaml is missing."
    echo "error: first run 'openshift-install create install-config'"
    exit 1
fi

set -eux

if [[ -z "${RUNNING_UNDER_SCRIPT:-}" ]]; then
    export RUNNING_UNDER_SCRIPT=1
    if [[ "$(uname -s)" == "Darwin" ]]; then
	exec script typescript "$0" "$@"
    else
	exec script -c "$0 $@"
    fi
fi

export KUBECONFIG="$PWD/auth/kubeconfig"

approve_csr_subshell_pid=0

function print_env {
    set +u
    for var_name in CLUSTER_NAME AZURE_REGION BASE_DOMAIN BASE_DOMAIN_RESOURCE_GROUP PATH INFRA_ID RESOURCE_GROUP ACCOUNT_KEY OCP_ARCH VHD_URL PRINCIPAL_ID RESOURCE_GROUP_ID VHD_BLOB_URL STORAGE_ACCOUNT_ID AZ_ARCH PUBLIC_IP PUBLIC_IP_ROUTER BOOTSTRAP_URL BOOTSTRAP_IGNITION MASTER_IGNITION; do
	echo "export ${var_name}=\"${!var_name}\""
    done | tee -a "${CLUSTER_NAME:-cluster}-env.sh"
}

function trap_handler {
    print_env
    kill $approve_csr_subshell_pid
}

trap 'trap_handler' INT EXIT

for i in 01_vnet.json 02_storage.json 03_infra.json 04_bootstrap.json 05_masters.json 06_workers.json; do
    if ! [[ -f "$i" ]]; then
	echo "Downloading $i"
	curl -s -O "https://raw.githubusercontent.com/openshift/installer/${RELEASE:-master}/upi/azure/$i"
    fi
done

# Extract data from install config
export CLUSTER_NAME=`yq -r .metadata.name install-config.yaml`
export AZURE_REGION=`yq -r .platform.azure.region install-config.yaml`
export BASE_DOMAIN=`yq -r .baseDomain install-config.yaml`
export BASE_DOMAIN_RESOURCE_GROUP=`yq -r .platform.azure.baseDomainResourceGroupName install-config.yaml`

# Empty the compute pool
yq e '.compute[0].replicas = 0' -i install-config.yaml

# Create manifests
openshift-install create manifests

# Remove control plane machines and machinesets
rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml
rm -f openshift/99_openshift-cluster-api_worker-machineset-*.yaml
rm -f openshift/99_openshift-machine-api_master-control-plane-machine-set.yaml

# Make control-plane nodes unschedulable
yq e '.spec.mastersSchedulable = false' -i manifests/cluster-scheduler-02-config.yml

# Remove DNS Zones
yq e 'del(.spec.publicZone, .spec.privateZone)' -i manifests/cluster-dns-02-config.yml

# Resource Group Name and Infra ID
export INFRA_ID=`yq -r '.status.infrastructureName' manifests/cluster-infrastructure-02-config.yml`
export RESOURCE_GROUP=`yq -r '.status.platformStatus.azure.resourceGroupName' manifests/cluster-infrastructure-02-config.yml`

# Create ignition configs
openshift-install create ignition-configs

# Create The Resource Group and identity
az group create --name $RESOURCE_GROUP --location $AZURE_REGION
az identity create -g $RESOURCE_GROUP -n ${INFRA_ID}-identity

# Upload the files to a Storage Account
az storage account create -g $RESOURCE_GROUP --location $AZURE_REGION --name ${CLUSTER_NAME}sa --kind Storage --sku Standard_LRS
export ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP --account-name ${CLUSTER_NAME}sa --query "[0].value" -o tsv`

# Copy the cluster image
export OCP_ARCH="x86_64"
az storage container create --name vhd --account-name ${CLUSTER_NAME}sa
export VHD_URL=$(openshift-install coreos print-stream-json | jq -r --arg arch "$OCP_ARCH" '.architectures[$arch]."rhel-coreos-extensions"."azure-disk".url')
az storage blob copy start --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY --destination-blob "rhcos.vhd" --destination-container vhd --source-uri "$VHD_URL"
date
sleep 600
status="unknown"
while [ "$status" != "success" ]
do
    date
    status=`az storage blob show --container-name vhd --name "rhcos.vhd" --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -o tsv --query properties.copy.status`
    echo $status
    [[ "$status" != "success" ]] & sleep 5
done
date

# Upload the bootstrap ignition
az storage container create --name files --account-name ${CLUSTER_NAME}sa
az storage blob upload --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -c "files" -f "bootstrap.ign" -n "bootstrap.ign"

# Create the DNS zones
az network dns zone create -g $BASE_DOMAIN_RESOURCE_GROUP -n ${CLUSTER_NAME}.${BASE_DOMAIN}
az network private-dns zone create -g $RESOURCE_GROUP -n ${CLUSTER_NAME}.${BASE_DOMAIN}

# Grant access to the identity
export PRINCIPAL_ID=`az identity show -g $RESOURCE_GROUP -n ${INFRA_ID}-identity --query principalId --out tsv`
export RESOURCE_GROUP_ID=`az group show -g $RESOURCE_GROUP --query id --out tsv`
az role assignment create --assignee "$PRINCIPAL_ID" --role 'Contributor' --scope "$RESOURCE_GROUP_ID"

# Deploy the Virtual Network
az deployment group create -g $RESOURCE_GROUP \
   --template-file "01_vnet.json" \
   --parameters baseName="$INFRA_ID"
az network private-dns link vnet create -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n ${INFRA_ID}-network-link -v "${INFRA_ID}-vnet" -e false

# Deploy the image
export VHD_BLOB_URL=`az storage blob url --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -c vhd -n "rhcos.vhd" -o tsv`
export STORAGE_ACCOUNT_ID=`az storage account show -g ${RESOURCE_GROUP} --name ${CLUSTER_NAME}sa --query id -o tsv`
export AZ_ARCH=`echo $OCP_ARCH | sed 's/x86_64/x64/;s/aarch64/Arm64/'`

az deployment group create -g $RESOURCE_GROUP \
   --template-file "02_storage.json" \
   --parameters vhdBlobURL="$VHD_BLOB_URL" \
   --parameters baseName="$INFRA_ID" \
   --parameters storageAccount="${CLUSTER_NAME}sa" \
   --parameters architecture="$AZ_ARCH"

# Deploy the load balancers
az deployment group create -g $RESOURCE_GROUP \
   --template-file "03_infra.json" \
   --parameters privateDNSZoneName="${CLUSTER_NAME}.${BASE_DOMAIN}" \
   --parameters baseName="$INFRA_ID"

export PUBLIC_IP=`az network public-ip list -g $RESOURCE_GROUP --query "[?name=='${INFRA_ID}-master-pip'] | [0].ipAddress" -o tsv`
az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${BASE_DOMAIN} -n api.${CLUSTER_NAME} -a $PUBLIC_IP --ttl 60

# Launch the temporary cluster bootstrap
if [[ "$(uname -s)" == "Darwin" ]]; then
    bootstrap_url_expiry=`date -u -v+10H "+%Y-%m-%dT%H:%MZ"`
else
    bootstrap_url_expiry=`date -u -d "10 hours" '+%Y-%m-%dT%H:%MZ'`
fi

export BOOTSTRAP_URL=`az storage blob generate-sas -c 'files' -n 'bootstrap.ign' --https-only --full-uri --permissions r --expiry $bootstrap_url_expiry --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -o tsv`
export BOOTSTRAP_IGNITION=`jq -rcnM --arg v "3.1.0" --arg url $BOOTSTRAP_URL '{ignition:{version:$v,config:{replace:{source:$url}}}}' | base64 | tr -d '\n'`

az deployment group create -g $RESOURCE_GROUP \
   --template-file "04_bootstrap.json" \
   --parameters bootstrapIgnition="$BOOTSTRAP_IGNITION" \
   --parameters baseName="$INFRA_ID"

# Launch the permanent control plane
export MASTER_IGNITION=`cat master.ign | base64 | tr -d '\n'`

az deployment group create -g $RESOURCE_GROUP \
   --template-file "05_masters.json" \
   --parameters masterIgnition="$MASTER_IGNITION" \
   --parameters baseName="$INFRA_ID"

openshift-install wait-for bootstrap-complete --log-level debug

# Delete bootstrap resources
az network nsg rule delete -g $RESOURCE_GROUP --nsg-name ${INFRA_ID}-nsg --name bootstrap_ssh_in
az vm stop -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm deallocate -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap --yes
az disk delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap_OSDisk --no-wait --yes
az network nic delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-nic --no-wait
az storage blob delete --account-key $ACCOUNT_KEY --account-name ${CLUSTER_NAME}sa --container-name files --name bootstrap.ign
az network public-ip delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-ssh-pip

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
