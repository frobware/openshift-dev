#!/usr/bin/env bash

function check_all_vms_status() {
    local resource_group
    resource_group=$1

    if [ -z "$resource_group" ]; then
        echo "Error: Resource group not provided"
        return 1
    fi

    while true; do
        local vm_list
        vm_list=$(az vm list --resource-group "$resource_group" --query "[].{Name:name}" -o tsv)
        local all_running=true

        for vm_name in $vm_list; do
	    echo -n "Checking VM $vm_name: status="
            local status
            status=$(az vm get-instance-view --name "$vm_name" --resource-group "$resource_group" --query instanceView.statuses[1].code --output tsv)
            local power_state
            power_state=$(echo "$status" | cut -d '/' -f 2)
	    echo "$power_state"
            if [ "$power_state" != "running" ]; then
                all_running=false
            fi
        done

        if $all_running; then
            echo "All VMs in the resource group are running."
            break
        else
            echo "Not all VMs are running. Checking again in 15 seconds."
            sleep 15
        fi
    done
}

check_all_vms_status "$1"
