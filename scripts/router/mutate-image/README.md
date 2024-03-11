# mutate-image

## Overview

The `mutate-image.bash` script allows you to take an existing
container image, run it with a temporary name, execute a user-defined
script inside the container, and then commit the changes to create a
new image. This tool is particularly useful for customising container
images on the fly without directly modifying the original image.

## Prerequisites

- `podman` must be installed on your system.

## Usage

```bash
$ mutate-image.bash <original-image-name> <new-image-name> </path/to/script/to/run/in/the/container>
```

### Parameters:
- `<original-image-name>`: The fully qualified name or ID of the original container image you wish to modify.
- `<new-image-name>`: The name you wish to assign to the new, modified container image.
- `</path/to/script/to/run/in/the/container>`: The absolute path to the script you want to run inside the container. This script will make the desired changes within the container.

### Example:

```bash
$ mutate-image.bash quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:7d5d2a2a2c436be49fd85abe60629fd497d0e63790a07417cbfffcac32b8aef9 tmp-image downgrade-haproxy-to-2.2.19.sh
```

In this example, the script:

- Starts a container based on the image specified by the SHA digest
  from the `quay.io/openshift-release-dev/ocp-v4.0-art-dev`
  repository.

- Executes the script within a temporary container derived from the
  original image.

- Commits the changes made by to a new image named `tmp-image`.

### Logged example

```console
$ mutate-image.bash quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:7d5d2a2a2c436be49fd85abe60629fd497d0e63790a07417cbfffcac32b8aef9 tmp ~/downgrade-haproxy-to-2.2.19.sh
++ rpm -qa
++ grep haproxy
+ pkg=haproxy22-2.2.24-3.rhaos4.12.el8.x86_64
+ rpm -e haproxy22-2.2.24-3.rhaos4.12.el8.x86_64
+ rpm -ivh https://github.com/frobware/haproxy-builds/raw/master/rhaos-4.10-rhel-8/haproxy22-2.2.19-4.el8.x86_64.rpm
Retrieving https://github.com/frobware/haproxy-builds/raw/master/rhaos-4.10-rhel-8/haproxy22-2.2.19-4.el8.x86_64.rpm
Verifying...                          ########################################
Preparing...                          ########################################
Updating / installing...
haproxy22-2.2.19-4.el8                ########################################
+ setcap cap_net_bind_service=ep /usr/sbin/haproxy
Getting image source signatures
Copying blob e2e51ecd22dc skipped: already exists
Copying blob d3fbfed1573d skipped: already exists
Copying blob 2593f2dd7adf skipped: already exists
Copying blob 1a10d5163d20 skipped: already exists
Copying blob c5f0b6f0bc75 skipped: already exists
Copying blob 129fa6343b80 skipped: already exists
Copying blob 4798abf1087c done   |
Copying config 03f3b8636b done   |
Writing manifest to image destination
03f3b8636be37cb84a8b7ebf38ccc4e3fca375783c09d41ed771b9ac27bedeb1
tmp-container-name-29512
New image created: tmp

$ podman run -it --rm --entrypoint /bin/bash tmp
bash-4.4$ haproxy -v
HA-Proxy version 2.2.19-7ea3822 2021/11/29 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2025.
Known bugs: http://www.haproxy.org/bugs/bugs-2.2.19.html
Running on: Linux 6.7.7 #1-NixOS SMP PREEMPT_DYNAMIC Fri Mar  1 12:42:00 UTC 2024 x86_64
bash-4.4$
```

And my `downgrade-haproxy-to-2.2.19.sh` contains:

```bash
#!/usr/bin/env bash
set -eux
pkg=$(rpm -qa | grep haproxy)
rpm -e $pkg
rpm -ivh https://github.com/frobware/haproxy-builds/raw/master/rhaos-4.10-rhel-8/haproxy22-2.2.19-4.el8.x86_64.rpm
setcap 'cap_net_bind_service=ep' /usr/sbin/haproxy
```

## Important Notes

- This process runs the temporary container as root to ensure
  sufficient permissions for modifications, such as replacing binaries
  or modifying configurations.
- After the new image is created, the temporary container used for the
  modifications is automatically removed.
