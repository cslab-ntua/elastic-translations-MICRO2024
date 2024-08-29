#!/bin/bash

cleanup() {
	pkill -f spawnvm.sh
	pkill -f run.sh

}
trap cleanup EXIT

# FIXME: move these to a common source-able file
ok() {
	echo -e "[\033[0;32mOK\033[0m] ${@}"
}

fail() {
	echo -e "[\033[0;31mFAILED\033[0m] ${@}"
	exit 1
}

check() {
	[ $# -eq 2 -o $# -eq 3 ] || fail "internal: invalid check args"
	cmd="${1}"
	msg="${2}"
	[ -z ${3} ] && fmsg="${msg}"

	eval ${cmd} && ok "${msg}" || fail "${fmsg}"
}

# These are normally set by run.sh for the native results, so make sure we use
# tcmalloc for Qemu / host as well
export LD_PRELOAD="${BASE}/lib/libtcmalloc_minimal.so:${LD_PRELOAD}"
export TCMALLOC_NORELEASE=1
source "${BASE}/env/tcmalloc.env"

# We spawn a new VM for each benchmark
for benchmark in ${BENCHMARKS}; do
	export benchmark

	# Disable THP for 4KiB and 64KiB
	if [[ "${PGSZ}" == "pte" || "${PGSZ}" == "hptec" ]]; then
		export GUEST_THP=never
		export HOST_THP=never
	else
		export GUEST_THP=always
		export HOST_THP=always
	fi

	# Total VM memory
	export MEM_GB=200
	# VM memory backed by HugeTLB
	export GUEST_HTLB_MEM_GB=180

	# FIXME: move these to a common source-able file
	pgsz=$(getconf PAGESIZE)
	pgszkb=$(( ${pgsz} >> 10 ))
	[ ${pgszkb} -eq 4 -o ${pgszkb} -eq 16 -o ${pgszkb} -eq 64 ] || fail "invalid page size: ${pgsz}"
	hpmdszkb=$(( $(cat /sys/kernel/mm/transparent_hugepage/hpage_pmd_size) >> 10 ))
	if [ ${pgszkb} -eq 4 ]; then
		hptecszkb=64
		hpmdcszkb=$(( ${hpmdszkb} * 16 ))
		hpudszkb=$(( 1 << 20 ))
	else
		hptecszkb=$(( 2 * 1024 ))
		hpmdcszkb=$(( ${hpmdszkb} * 32 ))
	fi
	ok "pgsz: ${pgszkb}KB, hptecsz: ${hptecszkb}KB, hpmdsz: ${hpmdszkb}KB, hpmdcsz: ${hpmdcszkb}KB, hpudsize: ${hpudszkb}KB"

	case "${PGSZ}" in
		"hptec")
			export HOST_HTLB_PGSIZE_KB=${hptecszkb}
			export GUEST_HTLB_PGSIZE_KB=${hptecszkb}
			;; 
		"hpmd")
			export HOST_HTLB_PGSIZE_KB=${hpmdszkb}
			export GUEST_HTLB_PGSIZE_KB=${hpmdszkb}
			;; 
		"hpmdc")
			export HOST_HTLB_PGSIZE_KB=${hpmdcszkb}
			export GUEST_HTLB_PGSIZE_KB=${hpmdcszkb}
			;;
		"hpud")
			[ ! $pgszkb -eq 4 ] && fail "pagesize doesn't support PUDs"
			export HOST_HTLB_PGSIZE_KB=${hpudszkb}
			export GUEST_HTLB_PGSIZE_KB=${hpudszkb}
			export hpud=1
			;;
	esac

	KERNEL="5.18.19-et" spawnvm.sh run-fig2.sh
done

exit 0
