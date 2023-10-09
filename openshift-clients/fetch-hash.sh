#!/usr/bin/env bash

set -eu

if [[ $# -eq 0 ]]; then
    echo "Usage: ${0##*/} <OCP-VERSION>"
    exit 1
fi

for arch in aarch64 x86_64; do
    for system in mac linux; do
	for version in "$@"; do
	    filename="openshift-client-${system}.tar.gz"
	    if [[ $arch == "aarch64" ]]; then
		filename="openshift-client-${system}-arm64.tar.gz"
	    fi
	    url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$version/$filename"
	    hash=$(nix hash to-sri --type sha256 "$(nix-prefetch fetchurl --type sha256 --quiet --url "$url")")
	    if [[ $system =~ mac ]]; then
		system=darwin
	    fi
	    echo "${arch}-${system} = \"$hash\";"
	done
    done
done
