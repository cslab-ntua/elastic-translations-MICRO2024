#!/bin/bash
# Fig. 10: ET virtualized execution performance

set -o pipefail -o errexit

ok() {
        echo -e "[\033[0;32mOK\033[0m] ${@}"
}

fail() {
        echo -e "[\033[0;31mFAILED\033[0m] ${@}"
        exit 1
}

cleanup() {
	FAILED=0
	[ $? -ne 0 ] && FAILED=1
	pkill -f spawnvm.sh
	pkill -f run.sh
	while popd &>/dev/null; do true; done
	clear_htlb.sh
	[ ${FAILED} -eq 1 ] && fail "${0} failed, exiting..."
	ok "${0} finished, exiting..."
}
trap cleanup EXIT

# init env
# This script will get called again inside the VM, to actually call run.sh
if [ "${TYPE}" == "vm" ]; then
	export BASE="/host"
else
	export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
fi
source "${BASE}/env/base.env"
pushd "${BASE}"

# For Fig. 10, we target a non-fragmented machine -- unset frag target
unset FRAG_TARGET

# Directory where results will be stored -- it's prefixed by
# $(pwd)/results/host for native and $(pwd)/results/native for virtualized
# execution
export RESULTS="fig10"

# Use THP baseline config
export PGSZ=thp
export HOST_THP=always
export GUEST_THP=always

# Disable verbose kernel logging (pr_debug()) for ET by default. Set these to
# enable it. It requires the DEBUG_COALAPAGING / DEBUG_ET kernel config options
# to actually take effect
unset CADBG
unset PRDBG

# Default config for the evaluation
export KHUGE=1 # enable khugepaged
export KHUGE_SLEEP=1000 # 1ms khugepaged sleep / alloc interval
export KHUGE_HWK=1 # enable the khugepaged aggressive scanning / sleep behavior from Hawkeye for everyone
export NOKCOMPACTD=1 # Disable kcompactd noise (proactive compaction, etc.)

# Hawkeye config (shouldn't have effect for non-hwk runs)
export HWK_THP=1 # enable THP allocations by default
export HWK_SLEEP=1000 # same as KHUGE_SLEEP
export HWK_FALLBACK=0 # whether to fallback to normal khugepaged scanning when Hawkeye buckets are emty

# ET config
export COALA_KHUGE=1 # Enable khugepaged for ET mm's
export COALA_KHUGE_ETHEAP_ASYNC=1

# Do 3 iterations per benchmark / scenario
# FIXME: 
export ITER=1

if [ "${TYPE}" == "vm" ]; then
	if [[ ! -z "${MODE}" && "${MODE}" == "etheap" ]]; then
		# inside the VM we use regular ET, i.e. with online Leshy
		unset MODE
		unset COALA_KHUGE
		unset COALA_KHUGE_ETHEAP_ASYNC

		export UNHINTED_FAULTS=1
		export MODE="etonline"
		run.sh
	fi
	exit 0
fi

# Define the workloads to run
export BENCHMARKS="astar omnetpp streamcluster hashjoin svm canneal xsbench bfs gups btree"

# These are normally set by run.sh for the native results, so make sure we use
# tcmalloc for Qemu / host as well
export LD_PRELOAD="${BASE}/lib/libtcmalloc_minimal.so:${LD_PRELOAD}"
export TCMALLOC_NORELEASE=1
source "${BASE}/env/tcmalloc.env"

# We spawn a new VM for each benchmark
for benchmark in ${BENCHMARKS}; do
	export benchmark

	# Total VM memory
	export MEM_GB=200
	case "${RUN}" in
		"baseline")
			# Baseline
			unset MODE
			spawnvm.sh run-fig10-virt.sh
			;;
		"et")
			# ET (requires -et kernel on the host)
			case ${benchmark} in
				# Optional, use this to run Qemu with 64KiB ET translations
				#astar|omnetpp|streamcluster)
				#	echo "Disabling THP..."
				#	export HOST_THP=never
				#	export GUEST_THP=never
				#	;;
				*)
					echo "Enabling THP..."
					export HOST_THP=always
					export GUEST_THP=always
					;;
			esac
			KERNEL="5.18.19-et" MODE="etheap" ETHEAP=1 spawnvm.sh run-fig10-virt.sh
			;;
		"hwk")
			# Hawkeye (requires -hwk kernel on the host)
			KERNEL="5.18.19-hwk" MODE="hwk" spawnvm.sh run-fig10-virt.sh
			;;
	esac
done
