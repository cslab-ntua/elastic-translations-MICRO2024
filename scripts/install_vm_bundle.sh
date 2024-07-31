#/bin/bash
# 
# Download and unpack the VM bundle

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

install_vm_bundle() {
	if [ ! -d artifact-vm-bundle ]; then  
		ok "Downloading and unpacking VM bundle..."
		${WGET} "${FILE_HOST}/artifact-vm-bundle.tzst" | tar --zstd -xf -
	fi
}
install_vm_bundle
