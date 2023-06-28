#!/usr/bin/env bash

KUBECONFIG="${1}"

echo "Approving all CSR requests until bootstrapping is complete..."
while :
do
    oc --insecure-skip-tls-verify --kubeconfig="$KUBECONFIG" get csr --no-headers | grep Pending | \
	awk '{print $1}' | \
	xargs --no-run-if-empty oc --insecure-skip-tls-verify --kubeconfig="$KUBECONFIG" adm certificate approve
    sleep 1
done
