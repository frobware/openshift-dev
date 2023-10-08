#!/usr/bin/env bash

for arch in aarch64 x86_64; do
    for system in mac linux; do
	for version in $1; do
	    filename="openshift-client-${system}.tar.gz"
	    if [[ $arch == "aarch64" ]]; then
		filename="openshift-client-${system}-arm64.tar.gz"
	    fi
	    url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$version/$filename"
	    hash="$(nix-prefetch-url-as-sri-hash $url 2>&1 | grep -v 'path is' | awk '{print $2}')"
	    if [[ $system =~ mac ]]; then
		system=darwin
	    fi
	    echo "${arch}-${system} = \"$hash\";";
	done
    done
done
