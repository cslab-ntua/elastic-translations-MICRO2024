#!/bin/bash
# ET multiprogrammed evaluation

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

	pkill -feg0 frag2.sh
	pkill -feg0 memfrag.new
	pkill -feg0 run.sh
	pkill -feg0 run-benchmarks.sh
	pkill -feg0 hashjoin
	pkill -feg0 train
	pkill -feg0 canneal
	pkill -feg0 XSBench

	# FIXME: copied from run-benchmarks.sh
	ok "Killing spawned benchmarks..."
	pkill -TERM -fe -g0 astar
	pkill -TERM -fe -g0 omnetpp
	pkill -TERM -fe -g0 streamcluster
	pkill -TERM -fe -g0 train
	pkill -TERM -fe -g0 hashjoin
	pkill -TERM -fe -g0 gpasend
	pkill -TERM -fe -g0 pagecollect
	pkill -TERM -fe -g0 thpmaps
	pkill -TERM -fe -g0 canneal
	pkill -TERM -fe -g0 XSBench
	pkill -TERM -fe -g0 graph500
	pkill -TERM -fe -g0 BTree
	pkill -TERM -fe -g0 gups
	pkill -TERM -fe -g0 pr
	pkill -TERM -fe -g0 bfs
	pkill -TERM -fe -g0 cc
	pkill -TERM -fe -g0 sssp
	pkill -TERM -fe -g0 epochs
	pkill -TERM -fe -g0 valkey.sh
	pkill -KILL -fe -g0 valkey-server
	pkill -TERM -fe -g0 memcached.sh
	pkill -TERM -fe -g0 memcached
	pkill -TERM -fe -g0 oleshy

	echo 0 > /sys/module/coalapaging/parameters/khuge_etheap_async
	echo 0 > /sys/module/coalapaging/parameters/khuge_rr

	while popd &>/dev/null; do true; done
	[ ${FAILED} -eq 1 ] && fail "${0} failed, exiting..."
	ok "${0} finished, exiting..."
}
trap cleanup EXIT

# init env
export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
source "${BASE}/env/base.env"
pushd "${BASE}"

# FIXME: Refactor this into something less ugly
[ ! -z "${FRAG_TARGET}" ] && frag2.sh &
[ ! -z "${FRAG_TARGET}" ] && sleep 120

# Enable khugepaged round-robin for ET mm's
echo 1 > /sys/module/coalapaging/parameters/khuge_rr
# Enable khugepaged greedy ET 32MiB promotion
echo 1 > /sys/module/coalapaging/parameters/khuge_etheap_async

# non-fragmented host for the multiprogrammed scenario
unset FRAG_TARGET

# Directory where results will be stored -- it's prefixed by
# $(pwd)/results/host for native and $(pwd)/results/native for virtualized
# execution
export RESULTS="multi/"

# Do 3 iterations per benchmark / scenario
# FIXME: Set to 1 for now to finalize the scripts
export ITER=1

export PGSZ=thp

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

# Mix 1
case "${RUN}" in
	"baseline")
		# Baseline (THP)
		# Kernel Requirement: 5.18.19-vanilla (or -et)
		TASKSET_CORE=3 BENCHMARKS="xsbench" run.sh &
		TASKSET_CORE=13 BENCHMARKS="hashjoin" run.sh &
		wait
		;;
	"et")
		# ET
		# Kernel Requirement: 5.18.19-et kernel
		# KERNEL="et" ./scripts/build.sh
		TASKSET_CORE=3 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="xsbench" run.sh &
		TASKSET_CORE=13 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="hashjoin" run.sh &
		wait
		;;
esac

# Mix 2
case "${RUN}" in
	"baseline")
		# Baseline (THP)
		# Kernel Requirement: 5.18.19-vanilla (or -et)
		TASKSET_CORE=3 BENCHMARKS="astar" run.sh &
		TASKSET_CORE=13 BENCHMARKS="btree" run.sh &
		TASKSET_CORE=23 BENCHMARKS="gups" run.sh &
		wait
		;;
	"et")
		# ET
		# Kernel Requirement: 5.18.19-et kernel
		# KERNEL="et" ./scripts/build.sh
		TASKSET_CORE=3 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="astar" run.sh &
		TASKSET_CORE=13 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="btree" run.sh &
		TASKSET_CORE=23 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="gups" run.sh &
		wait
		;;
esac

# Mix 3
case "${RUN}" in
	"baseline")
		# Baseline (THP)
		# Kernel Requirement: 5.18.19-vanilla (or -et)
		TASKSET_CORE=3 BENCHMARKS="omnetpp" run.sh &
		TASKSET_CORE=13 BENCHMARKS="svm" run.sh &
		TASKSET_CORE=23 BENCHMARKS="bfs" run.sh &
		TASKSET_CORE=33 BENCHMARKS="gups" run.sh &
		wait
		;;
	"et")
		# ET
		# Kernel Requirement: 5.18.19-et kernel
		# KERNEL="et" ./scripts/build.sh
		TASKSET_CORE=3 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="omnetpp" run.sh &
		TASKSET_CORE=13 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="svm" run.sh &
		TASKSET_CORE=23 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="bfs" run.sh &
		TASKSET_CORE=33 UNHINTED_FAULTS=1 MODE="etonline" BENCHMARKS="gups" run.sh &
		wait
		;;
esac
