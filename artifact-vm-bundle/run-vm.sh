#!/bin/bash
# Run a EFI VM which boots to GRUB

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
		-drive if=pflash,format=raw,file=efi.img,readonly=on \
		-drive if=pflash,format=raw,file=varstore.img \
		"${@}" # user-provided args
