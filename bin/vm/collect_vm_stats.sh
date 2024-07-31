#!/bin/bash

i=0
while true; do
	until taskset -c 40 gparecv 2>/dev/null >> "./results/vm/${RESULTS}/gpadump"; do
		sleep 10
	done

	if [[ ! -s "./results/vm/${RESULTS}/gpadump" ]]; then
		sleep 10
		continue
	fi

	mv "./results/vm/${RESULTS}/gpadump" "./results/vm/${RESULTS}/gpadump-$$-$i"

	taskset -c 36 sptecollect /sys/kernel/debug/kvm/*/sptdump "./results/vm/${RESULTS}/sptdump-$$-$i" &
	taskset -c 35 pagecollect $(pgrep "qemu-") | tee "./results/vm/${RESULTS}/qemudump-$$-$i"

	i=$(( $i + 1 ));
	sleep 10
done
