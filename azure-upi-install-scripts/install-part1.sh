#!/usr/bin/env bash

set -eux

# https://github.com/openshift/installer/blob/master/docs/user/azure/install_upi.md

if ! [[ -f install-config.yaml ]]; then
    echo "error: install-config.yaml is missing."
    echo "error: first run 'openshift-install create install-config'"
    exit 1
fi

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

export PATH=$PWD:$PATH

function print_env {
    set +u
    for var_name in CLUSTER_NAME AZURE_REGION BASE_DOMAIN BASE_DOMAIN_RESOURCE_GROUP PATH INFRA_ID RESOURCE_GROUP ACCOUNT_KEY OCP_ARCH VHD_URL PRINCIPAL_ID RESOURCE_GROUP_ID VHD_BLOB_URL STORAGE_ACCOUNT_ID AZ_ARCH PUBLIC_IP BOOTSTRAP_URL BOOTSTRAP_IGNITION MASTER_IGNITION; do
        echo "export ${var_name}=\"${!var_name}\""
    done | tee -a "${CLUSTER_NAME:-cluster}-env.sh"
}

trap print_env INT EXIT

# Empty the compute pool
python3 -c '
import yaml;
path = "install-config.yaml";
data = yaml.full_load(open(path));
data["compute"][0]["replicas"] = 0;
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Create manifests
openshift-install create manifests

# Remove control plane machines and machinesets
rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml
rm -f openshift/99_openshift-cluster-api_worker-machineset-*.yaml
rm -f openshift/99_openshift-machine-api_master-control-plane-machine-set.yaml

# Make control-plane nodes unschedulable
python3 -c '
import yaml;
path = "manifests/cluster-scheduler-02-config.yml";
data = yaml.full_load(open(path));
data["spec"]["mastersSchedulable"] = False;
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Remove DNS Zones
python3 -c '
import yaml;
path = "manifests/cluster-dns-02-config.yml";
data = yaml.full_load(open(path));
del data["spec"]["publicZone"];
del data["spec"]["privateZone"];
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

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

# export PUBLIC_IP=`az network public-ip list -g $RESOURCE_GROUP --query "[?name=='${INFRA_ID}-master-pip'] | [0].ipAddress" -o tsv`
# az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n api -a $PUBLIC_IP --ttl 60

export PUBLIC_IP=`az network public-ip list -g $RESOURCE_GROUP --query "[?name=='${INFRA_ID}-master-pip'] | [0].ipAddress" -o tsv`
az network dns record-set a add-record -g $BASE_DOMAIN_RESOURCE_GROUP -z ${BASE_DOMAIN} -n api.${CLUSTER_NAME} -a $PUBLIC_IP --ttl 60

# Launch the temporary cluster bootstrap
bootstrap_url_expiry=`date -u -d "10 hours" '+%Y-%m-%dT%H:%MZ'`
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

print_env
./install-part2.sh "${CLUSTER_NAME:-cluster}-env.sh"

