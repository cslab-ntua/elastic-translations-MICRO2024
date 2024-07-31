#!/bin/bash
# Configuration via the following env variables:
#	- HOST_THP: [never|madvise|always]
#	- GUEST_THP: [never|madvise|always] 
#	- MEM_GB: VM memory in GiB 
#	- GUEST_HTLB_MEM_GB: VM HTLB-backed memory in GiB
#	- GUEST_HTLB_PGSIZE_KB: Guest HTLB pagesize in KiB
#	- HOST_HTLB_PGSIZE_KB: Host HTLB pagesize in KiB
#	- NODE: NUMA node to use (0, 1, etc)
# 	- CPUS: number of cores

source $(dirname ${0})/scripts/common.sh

# FIXME: Add support for virtualized execution in the scripts
KERNEL="${BASE}/vm/vmlinuz-5.18.19-et"
#KERNEL="${BASE}/vm/vmlinuz-5.18.19-tr"
#KERNEL="${BASE}/vm/vmlinuz-5.18.19-hwk"

#APPEND="console=ttyAMA0 root=/dev/vda1 earlycon transparent_hugepage=${GUEST_THP} mitigations=off no_hash_pointers ignore_loglevel movablecore=199G"
APPEND="console=ttyAMA0 root=/dev/vda1 earlycon transparent_hugepage=${GUEST_THP} mitigations=off no_hash_pointers ignore_loglevel" #page_poison=1 page_owner=on"

QEMU="${BASE}/bin/vm/qemu-system-aarch64"

# FIXME: Add support for virtualized execution in the scripts
IMAGE="${BASE}/vm/jammy-vm.qcow2"
CLOUD_INIT="${BASE}/vm/cloud-init.img"

NODE="${NODE:-0}"
CPUS="${CPUS:-60}"
MEM_GB="${MEM_GB:-230}"

if [[ -n ${GUEST_HTLB_PGSIZE_KB} ]]; then
	NR_GUEST_HTLB_PAGES=$(( (${GUEST_HTLB_MEM_GB} << 20) / ${GUEST_HTLB_PGSIZE_KB} ))
	APPEND="${APPEND} default_hugepagesz=${GUEST_HTLB_PGSIZE_KB}k hugepagesz=${GUEST_HTLB_PGSIZE_KB}k hugepages=${NR_GUEST_HTLB_PAGES}"
fi

if [[ -n ${HOST_HTLB_PGSIZE_KB} ]]; then
	NR_HOST_HTLB_PAGES=$(( (${MEM_GB} << 20) / ${HOST_HTLB_PGSIZE_KB} ))
	MEMBACKEND="memory-backend-file,mem-path=/dev/hugepages,discard-data=on"

	echo "${NR_HOST_HTLB_PAGES}" > /sys/devices/system/node/node0/hugepages/hugepages-${HOST_HTLB_PGSIZE_KB}kB/nr_hugepages
	umount /dev/hugepages &>/dev/null || true
	mount -t hugetlbfs none /dev/hugepages -o rw,relatime,pagesize=${HOST_HTLB_PGSIZE_KB}k
else
	MEMBACKEND="memory-backend-ram"
fi

if [[ -n ${HOST_THP} ]]; then
	echo "${HOST_THP}" > /sys/kernel/mm/transparent_hugepage/enabled
fi

# -serial mon:unix:/tmp/serial.sock,server=on,wait=off
pushd "${BASE}/bin" &>/dev/null
exec numactl -N${NODE} -m${NODE} -- ${QEMU} -enable-kvm -M virt \
	-cpu host -smp ${CPUS} -m ${MEM_GB}g -nographic \
	-serial mon:stdio \
	-qmp unix:/tmp/qmp-sock,server=on,wait=off \
	-drive file=${IMAGE},if=virtio,format=qcow2,cache=none \
	-nic user,hostfwd=tcp:127.0.0.1:65433-:22,model=virtio \
	-virtfs local,path=${BASE},mount_tag=host,security_model=none \
	-kernel ${KERNEL} -append "${APPEND}" \
	-numa node,nodeid=0,memdev=mem \
	-object ${MEMBACKEND},id=mem,size=${MEM_GB}G,share=off,merge=off,dump=off,prealloc=off \
	-drive file=${CLOUD_INIT},format=raw,if=virtio,cache=none \
	-device vhost-vsock-pci,guest-cid=9999
