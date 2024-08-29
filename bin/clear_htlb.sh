#!/bin/bash
# Free any reserved htlb pages

set -o pipefail -o errexit

for d in /sys/kernel/mm/hugepages/hugepages-*; do
	echo 0 > "${d}/nr_hugepages"
done
