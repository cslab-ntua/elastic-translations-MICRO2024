#!/bin/bash

cleanup() {
	pkill collect
	pkill -P $$
	kill -SIGTERM $(jobs -p) &>/dev/null || true
	rm -f /tmp/qmp-sock
}
trap cleanup EXIT

echo 1 > /proc/sys/vm/overcommit_memory
echo 1000000 > /proc/sys/vm/max_map_count
echo 0 > /proc/sys/kernel/randomize_va_space

echo "Waiting for old VM to stop..."
while pgrep --full qmp-sock &>/dev/null; do
	sleep 1
done
qemu.sh &
echo "Spawned VM..."
sleep 5
pincpus.py /tmp/qmp-sock $(( ${NODE:-0} * 80 )) &
echo "Pinning vCPUs, waiting for VM to boot..."

until pgrep --full 'qemu.*qmp-sock'&>/dev/null; do
	sleep 1
done

prctl.sh $(pgrep 'qemu-')

SSHCMD="ssh -oNoHostAuthenticationForLocalhost=yes -p65433 root@localhost"

until ${SSHCMD} "mount /host &>/dev/null"; do
	sleep 1
done

echo "VM is up..."

[ ! -z "${MODE}" ] && collect_vm_stats.sh &

ENVS="TYPE=vm BENCHMARKS=${benchmark} PGSZ=${PGSZ}"
if [[ ! -z "${MODE}" ]]; then
	ENVS="${ENVS} MODE=${MODE}"
fi
if [[ "${PGSZ}" -eq "hpud" ]]; then
	ENVS="${ENVS} hpud=1"
fi
echo "${ENVS} /host/run-scripts/run-rev-vm.sh"
${SSHCMD} "${ENVS} /host/run-scripts/run-rev-vm.sh"

${SSHCMD} "poweroff"

while pgrep --full 'qemu.*qmp-sock'&>/dev/null; do
	sleep 1
done
