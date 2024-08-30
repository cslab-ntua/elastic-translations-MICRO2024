#!/bin/bash
# ET performance vs baseline / SOTA for native execution. Use the RUN env
# variable to select between:
#   i) baseline:  THP
#  ii) mTHP: requires 6.8/6.9-rc mTHP kernel
# iii) et: requires 5.18.19-et kernel
#  iv) hawkeye: requires 5.18.19-hwk kernel
#   v) trident: requires 4.17.x-tr kernel
#
# The runs can be tweaked to generate the results for
#   i) Fig. 8: native, unset FRAG_TARGET
#  ii) Fig. 11: native, FRAG_TARGET=50, FRAG_TARGET=99
# iii) Fig. 12: native, RUN=et, select between the various provided scenarios in the script
#  iv) Fig. 13: native, RUN=et, ACCESSBIT=1

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
	while popd &>/dev/null; do true; done
	[ ${FAILED} -eq 1 ] && fail "${0} failed, exiting..."
	ok "${0} finished, exiting..."
}
trap cleanup EXIT

# init env
export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
source "${BASE}/env/base.env"
pushd "${BASE}"

# Define the workloads to run
export BENCHMARKS="astar omnetpp streamcluster hashjoin svm canneal xsbench bfs gups btree"

# Set these to match the desired FMFI (0-100)
unset FRAG_TARGET

# Directory where results will be stored -- it's prefixed by
# $(pwd)/results/host for native and $(pwd)/results/native for virtualized
# execution
export RESULTS="eval/frag${FRAG_TARGET:-0}"

# Do 3 iterations per benchmark / scenario
# FIXME: Set to 1 for now to finalize the scripts
export ITER=1

# Use THP baseline config
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

# Hawkeye config (shouldn't have effect for non-hwk runs)
export HWK_THP=1 # enable THP allocations by default
export HWK_SLEEP=1000 # same as KHUGE_SLEEP
export HWK_FALLBACK=0 # whether to fallback to normal khugepaged scanning when Hawkeye buckets are emty

case "${RUN}" in
	"baseline")
		# Baseline (THP)
		# Kernel Requirement: 5.18.19-vanilla (or -et)
		run.sh # THP
		;;
	"mthp")
		# mTHP
		# Kernel Requirement: 6.8/6.9-rc mTHP-enabled kernel
		# FIXME: instructions to build, install and boot the artifact-provided mTHP # kernel
		PGSZ="thp-mthp" run.sh # THP faults by default, fallback to mTHP (64K)
		#PGSZ="mthp" run.sh # (optional) 64K mTHP faults only
		;;
	"et")
		# ET
		# Kernel Requirement: 5.18.19-et kernel
		# KERNEL="et" ./scripts/build.sh

		# ET (ET + online Leshy) base
		# online == bin/epochs.sh, run by bin/run.sh
		# profiling interval defined in bin/run.sh
		# slack + target defined by bin/epochs.sh when spwaning leshyv3 to generate hints
		UNHINTED_FAULTS=1 MODE="etonline" run.sh

		# (optional) ET with vanilla THP + khugepaged during init phase
		#UNHINTED_FAULTS=1 MODE="etonline" COALA_KHUGE=1 EXTRA=".init-2m" run.sh

		# (optional) ET with vanilla THP + khugepaged during init phase and when no hints are available
		#UNHINTED_FAULTS=1 MODE="etonline" COALA_KHUGE=1 KHUGE_FALLBACK=1 EXTRA=".fallback-2m" run.sh

		# (optional) ET (online) without using 32M translations
		#UNHINTED_FAULTS=1 MODE="etonline-2m" PGSZ="thp" EXTRA=".noet" run.sh

		# Offline Leshy with fautlt-time hinting
		export COALA_KHUGE=1
		MODE="leshy" run.sh

		# Offline Leshy with fault-time hinting and accessbit-based hints
		MODE="leshy" ACCESSBIT=1 run.sh

		# Offline Leshy without using 32MiB translations
		#MODE="leshy-thp" run.sh

		# Offline Leshy without fault-time hinting
		#MODE="leshy" UNHINTED_FAULTS=1 EXTRA=".nofaults" run.sh

		# ET greedy (without Leshy) with async migrations
		#MODE="etheap" EXTRA=".async-2m" run.sh

		# FIXME: ET greedy runs with 32m async
		#echo 1 > /sys/module/coalapaging/parameters/khuge_etheap_async
		#MODE="etheap" EXTRA=".async-32m" run.sh
		#echo 0 > /sys/module/coalapaging/parameters/khuge_etheap_async

		# ET greedy (without Leshy) without async migrations
		#unset COALA_KHUGE
		#MODE="etheap" EXTRA=".noasync" run.sh
		;;
	"hwk")
		# Hawkeye
		# Kernel Requirement: 5.18.19-hwk kernel
		# KERNEL="hwk" ./scripts/build.sh
		export MODE="hawkeye"
		run.sh
		#HWK_FALLBACK=1 run.sh # (optional) see earlier comment on HWK_FALLBACK
		;;
	"trident")
		# Trident
		# Kernel Requirement: 4.17-tr
		# FIXME: instructions to build, install and boot the artifact-provided
		# Trident kernel
		MODE="trident" run.sh
		;;
esac
