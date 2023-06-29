#!/usr/bin/env bash

set -eu

if [[ $# -eq 0 ]]; then
    echo "No resource group ID provided."
    exit 1
fi

resource_group="$1"; shift

loadBalancer=$(az network lb list --resource-group "$resource_group" --query "[0].{Name:name}" --output tsv)
echo "LoadBalancer=$loadBalancer"

backendPool=$(az network lb address-pool list --resource-group "$resource_group" --lb-name "$loadBalancer" --query "[0].{Name:name}" --output tsv)
echo "backendPool=$backendPool"

backendPoolID=$(az network lb address-pool show --resource-group "$resource_group" --lb-name "$loadBalancer" --name "$backendPool" --query id --output tsv)
echo "backendPoolID=$backendPoolID"

# List network interfaces in backend pool.
nics=$(az network nic list --query "[?ipConfigurations[0].loadBalancerBackendAddressPools[0].id=='$backendPoolID'].{id:id}" --output tsv)

echo "NICs associated with Backend Pool:"
echo "$nics"

# For each NIC, get the associated VM and the private IP address.
for nic in $nics; do
    vid=$(az network nic show --ids "$nic" --query "virtualMachine.id" --output tsv)
    name=$(echo "$vid" | cut -d "/" -f9)
    private_ipaddr=$(az network nic ip-config list --nic-name "$(echo "$nic" | cut -d "/" -f9)" --resource-group "$resource_group" --query "[].privateIpAddress" --output tsv)
    echo "VM Name: $name, Private IP: $private_ipaddr"
done
