# Install an OpenShift Azure UPI cluster

This is largely a regurgitation of the install steps listed in
https://github.com/openshift/installer/blob/master/docs/user/azure/install_upi.md
with some additional automation and retry logic (where necessary).

The installation steps are automatic once the initial
`openshift-install create install-config` step has been run.

## Prep

	$ git clone https://github.com/frobware/openshift-dev
	$ mkdir ~/azure-upi-install
	$ cd ~/azure-upi-install
	$ ln -s ../openshift-dev/azure-upi-install-scripts/*.sh .

## Download an OpenShift installer

The installation scripts assume that the openshift-installer binary is
in the current directory.

	# Download an openshift-installer binary
	$ wget https://openshift-release-artifacts.apps.ci.l2s4.p1.openshiftapps.com/4.14.0-0.nightly-2023-06-30-131338/openshift-install-linux-4.14.0-0.nightly-2023-06-30-131338.tar.gz

	$ tar xvfp openshift-install-linux-4.14.0-0.nightly-2023-06-30-131338.tar.gz
	README.md
	openshift-install

## Create an OpenShift install-config.yaml

**NOTE**: Cluster names cannot contain hypens. I have been using
mynameDDMMHHSS as a template.

	$ ./openshift-install create install-config
	? SSH Public Key  [Use arrows to move, type to filter, ? for more help]
	/home/aim/.ssh/id_rsa.pub
	...
	<answer all the questions>
	...
	INFO Install-Config created in: .

## Deploy the cluster

The remainder of the installation is automatic.

	./install.sh

This `install.sh` runs the remainder of the installation process to
completion--it also does this by re-exec'ing via `script(1)`. This
will leave a `typescript` file in the current directory that lists all
the steps and environment values generarted by the install steps. The
`typescript` file can be used to both observe installation progress,
and to help diagnose installation failures.

The `install.sh` script will also create an environment file
(`$CLUSTER_NAME-env.sh`) in the current directory that captures
pertinent environment variable values that are computed during
installation. This file is created when `install.sh` exits.

For example:

	export ACCOUNT_KEY="<redacted>"
	export INFRA_ID="amcdermo29061029-2lxxr"
	export OCP_ARCH="x86_64"
	export PRINCIPAL_ID="<redacted>"
	export RESOURCE_GROUP="amcdermo29061029-2lxxr-rg"
	export RESOURCE_GROUP_ID="/../resourceGroups/amcdermo29061029-2lxxr-rg"
	export STORAGE_ACCOUNT_ID="/.../resourceGroups/amcdermo29061029-2lxxr-rg/providers/Microsoft.Storage/storageAccounts/..."
	export VHD_URL="https://.../imagebucket/rhcos-414.92.202306141028-0-azure.x86_64.vhd"

If installation fails, for whatever reason, you can source this file
and continue the installation by manually running various steps from
the `install.sh` script.
