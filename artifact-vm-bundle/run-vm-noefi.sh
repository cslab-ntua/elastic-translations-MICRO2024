#!/bin/bash
# Run a non-EFI VM which directly boots to pre-built VM kernels on the host

export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
source "${BASE}/env/base.env"

exec numactl -N0 -m0 -- \
	${BASE}/bin/vm/qemu-system-aarch64 \
		-M virt,accel=kvm -cpu host -smp 60 -m 192g -nographic \
		-qmp unix:${BASE}/artifact-vm-bundle/qmp.sock,server=on,wait=off -serial mon:stdio \
		-drive file=${BASE}/artifact-vm-bundle/artifact.img,if=virtio,format=qcow2 \
		-nic user,hostfwd=tcp:127.0.0.1:65433-:22,model=virtio \
		-virtfs local,path="${BASE}",mount_tag=host,security_model=none \
		-device virtio-rng-pci -device vhost-vsock-pci,guest-cid=9999 \
		-kernel ${BASE}/artifact-vm-bundle/kernels/vmlinuz-5.18.19-etvm+ \
		-initrd ${BASE}/artifact-vm-bundle/kernels/initrd.img-5.18.19-etvm+ \
		-append 'console=ttyAMA0 root=/dev/vda1 earlycon transparent_hugepage=always mitigations=off no_hash_pointers ignore_loglevel' \
		"${@}" # user-provided args
