#!/bin/bash
# 
# Download and unpack the VM bundle

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

install_vm_bundle() {
	if [[ ! -d artifact-vm-bundle || ! -f artifact-vm-bundle/artifact.img ]]; then
		ok "Downloading and unpacking VM bundle..."
		# You can swap artifact-vm-bundle with artifact-vm-bund-full, which
		# includes the extracted / prepared repo
		${WGET} "${FILE_HOST}/artifact-vm-bundle.tzst" | tar --zstd -xf -
	fi
}
install_vm_bundle
