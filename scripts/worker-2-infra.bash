#!/usr/bin/env bash

set -eu

if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide a machineset name."
    exit 1
fi

machineset_name=$1; shift

: "${MACHINESET_NAMESPACE:="openshift-machine-api"}"

# Get all machines of the specified MachineSet
machines=$(oc get machine -n ${MACHINESET_NAMESPACE} -l machine.openshift.io/cluster-api-machineset="${machineset_name}" -o jsonpath='{.items[*].metadata.name}')

for machine in $machines
do
    echo "Processing machine $machine"

    # Get the node name associated with the machine
    node=$(oc get machine "$machine" -n ${MACHINESET_NAMESPACE} -o jsonpath='{.status.nodeRef.name}')

    if [ -z "$node" ]; then
	echo "No node associated with machine $machine. Skipping..."
	continue
    fi

    echo "Node associated with machine $machine: $node"

    # Add the infra label to the node
    oc label node --overwrite "$node" node-role.kubernetes.io/infra=""

    # Remove the worker label from the node
    oc label node "$node" node-role.kubernetes.io/worker-
done
