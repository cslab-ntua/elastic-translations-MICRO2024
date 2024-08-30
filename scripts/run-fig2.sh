#!/bin/bash
# Fig. 2: Performance of HugeTLB intermediate-sized translations on a
# non-fragmented machine.

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
# For frag2 we target a non-fragmented machine -- unset frag target
unset FRAG_TARGET
# We only use MODE for ET / Hawkeye / Trident
unset MODE

# Define the workloads to run
export BENCHMARKS="astar omnetpp streamcluster hashjoin svm canneal"

# Directory where results will be stored -- it's prefixed by
# $(pwd)/results/host for native and $(pwd)/results/native for virtualized
# execution
export RESULTS="fig2"

# Do 3 iterations per benchmark / scenario
export ITER=1

if [ "${TYPE}" == "vm" ]; then
	run.sh
	exit 0
fi

sizes="pte hptec thp hpmd hpmdc hpud"
for sz in ${sizes}; do
	clear_htlb.sh

	# PGSZ defines the requested translation (page) size to use, see bin/run.sh for
	# more info
	export PGSZ="${sz}"

	# run.sh is the main bash script which drives the artifact evaluation. It's
	# configured via environmental varibles, documented in run.sh
	#run.sh # native run

	# We use a separate script for the virtualized results
	$(dirname ${0})/run-fig2-vm.sh
	clear_htlb.sh
done
