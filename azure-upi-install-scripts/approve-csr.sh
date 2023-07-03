#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide a path to a kubeconfig file."
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "The provided argument is not a file or doesn't exist. Please provide a valid file."
    exit 1
fi

kubeconfig=$1; shift

echo "Approving all CSR requests until bootstrapping is complete..."
while :
do
    oc --insecure-skip-tls-verify --kubeconfig="$kubeconfig" get csr --no-headers | grep Pending | \
	awk '{print $1}' | \
	xargs --no-run-if-empty oc --insecure-skip-tls-verify --kubeconfig="$kubeconfig" adm certificate approve
    sleep 1
done
