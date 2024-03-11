#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <original-image-name> <new-image-name> </path/to/script/to/run/in/the/container>"
    exit 1
fi

original_image="$1"
new_image_name="$2"
script_path="$3"

if [ ! -f "$script_path" ]; then
    echo "Script file does not exist or is a directory: $script_path"
    exit 1
fi

script_dir=$(dirname "$script_path")
script_name=$(basename "$script_path")

entrypoint=$(podman inspect "$original_image" --format '{{json .Config.Entrypoint}}')

if [ -z "$entrypoint" ]; then
    entrypoint="[]"
fi

tmp_container_name="tmp-container-name-${RANDOM}$$"

# We need to run as root if we're going to replace a binary, or run
# setcap, et al.
podman run --user=root \
       -v "${script_dir}:/tmp/script_dir:Z" \
       --name $tmp_container_name \
       --entrypoint /bin/bash "$original_image" \
       -c "/tmp/script_dir/${script_name}"

podman commit \
       --change 'USER 1001' \
       --change "ENTRYPOINT $entrypoint" \
       --change 'CMD=[]' $tmp_container_name \
       "$new_image_name"

podman rm $tmp_container_name

echo "New image created: $new_image_name"
