#!/bin/bash
# Qemu VM spawner / helper
# Configuration via the following env variables:
#	- HOST_THP: [never|madvise|always]
#	- GUEST_THP: [never|madvise|always] 
#	- MEM_GB: VM memory in GiB 
#	- GUEST_HTLB_MEM_GB: VM HTLB-backed memory in GiB
#	- GUEST_HTLB_PGSIZE_KB: Guest HTLB pagesize in KiB
#	- HOST_HTLB_PGSIZE_KB: Host HTLB pagesize in KiB
#	- NODE: NUMA node to use (0, 1, etc)
# 	- CPUS: number of cores
#   - KERNEL: kernel to use

source $(dirname $(dirname $(dirname ${0})))/scripts/common.sh

KERNEL="${BASE}/artifact-vm-bundle/kernels/vmlinuz-${KERNEL}"
APPEND="console=ttyAMA0 root=/dev/vda1 earlycon transparent_hugepage=${GUEST_THP} mitigations=off no_hash_pointers ignore_loglevel"

QEMU="${BASE}/bin/vm/qemu-system-aarch64"
IMAGE="${BASE}/artifact-vm-bundle/artifact.img"

NODE="${NODE:-0}"
CPUS="${CPUS:-60}"
MEM_GB="${MEM_GB:-200}"

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

pushd "${BASE}/bin" &>/dev/null
exec numactl -N${NODE} -m${NODE} -- ${QEMU} -nographic -enable-kvm -M virt \
	-cpu host -smp ${CPUS} -m ${MEM_GB}g -numa node,nodeid=0,memdev=mem \
	-object ${MEMBACKEND},id=mem,size=${MEM_GB}G,share=off,merge=off,dump=off,prealloc=off \
	-serial mon:unix:${BASE}/artifact-vm-bundle/serial.sock,server=on,wait=off \
	-qmp unix:${BASE}/artifact-vm-bundle/qmp.sock,server=on,wait=off \
	-drive file=${IMAGE},if=virtio,format=qcow2,cache=none \
	-virtfs local,path=${BASE},mount_tag=host,security_model=none \
	-nic user,hostfwd=tcp:127.0.0.1:65433-:22,model=virtio \
	-kernel ${KERNEL} -append "${APPEND}" \
	-device virtio-rng-pci -device vhost-vsock-pci,guest-cid=9999 \
	"${@}" # user-provided args
