#!/bin/bash
#
# Dump the current configuration of THP and COALAPaging and ET

set -e

THP="/sys/kernel/mm/transparent_hugepage/"
ET="/sys/module/et/parameters/"
CA="/sys/module/coalapaging/parameters/"
HTLB="/sys/kernel/mm/hugepages/"

show_status() {
	echo "$1: "
	for f in $(find "${2}" -type f -perm -+r); do
		n="${f//${2}}"
		echo -ne "\t${n}: "
		cat $f
	done
}

show_all() {
	show_status "thp" "${THP}"
	if [ -d ${CA} ]; then
		show_status "coalapaging" "${CA}"
	fi
	if [ -d ${ET} ]; then
		show_status "et" "${ET}"
	fi
	show_status "htlb" "${HTLB}"
}

show_all
