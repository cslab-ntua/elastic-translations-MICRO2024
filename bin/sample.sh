#!/bin/bash
#
# Sample the benchmarks' TLB misses with ARM SPE or accesses with accessbit sampling 

set -e

source $(dirname ${0})/scripts/common.sh
export PERF="$(dirname ${0})/bin/perf"

# FIXME: cleanup

# Change this to wherever you want to store the samples / traces
TRACES=/dev/shm/traces
mkdir -p ${TRACES}

sample_misses() {
	name=$1
	shift

	# raw perf output
	raw="${TRACES}/${name}.misses.raw"
	# decoded perf output 
	dump="${TRACES}/${name}.misses.dump"
	# parsed sampled misses
	misses="${TRACES}/${name}.misses"

	if [[ "${name}" == "graph500" || "${name}" == "pr" ]]; then
		NUMA_PREFIX="numactl -N0 -m0"
		export OMP_NUM_THREADS=32
	else
		NUMA_PREFIX="numactl -N0 -m0 taskset -c 0"
		export OMP_NUM_THREADS=1
	fi

	# Set load_filter=1 to only sample loads
	# Set event_filter=0x20 to also sample speculatively executed instructions
	# Tweak cycles (-c 1024) to configure the sampling interval
	PERF_PREFIX="${PERF} stat -e cycles ${PERF} record -dBN -c 1024 -e arm_spe/jitter=1,event_filter=0x22/ -o ${raw}"

	# Run and sample
	ok "TLB miss sampling ${name}..."
	$NUMA_PREFIX $PERF_PREFIX -- $@

	# Decode
	ok "Running perf report..."
	${PERF} report -D -i "${raw}" > "${dump}"

	# Parse
	ok "Parsing perf report..."
	rg 'XLAT|VA' ${dump} | sed 's/.*\(VA\| LAT\)//' > ${misses}
}

sample_accesses() {
	name=$1
	shift

	# sampler output
	dump="${TRACES}/${name}.accesses.dump"
	# parsed sampled accesses
	accesses="${TRACES}/${name}.accesses"

	if [[ "${name}" == "graph500" || "${name}" == "pr" ]]; then
		NUMA_PREFIX="numactl -N0 -m0"
		export OMP_NUM_THREADS=32
	else
		NUMA_PREFIX="numactl -N0 -m0 taskset -c 0"
		export OMP_NUM_THREADS=1
	fi

	ok "Running ${name}..."
	$NUMA_PREFIX $@ &
	sleep 1

	pid=$(pgrep -f "^$1")
	if [[ -z "${pid}" ]]; then
		fail "Process ${name} not found..."
		exit 1
	fi

	ok "Access sampling ${pid}"
	idle "${pid}" > "${dump}"
	wait

	rg -v 'total|Error' "${dump}" > "${accesses}"
}

sample() {
	if [ ! -z "${ACCESSES}" ]; then
		sample_accesses $@
	else 
		sample_misses $@
	fi
}

ok "Setting CPU frequency..."
cpufreq-set -c 0 -f 2.7GHz || fail "Couldn't set CPU frequency..."

ok "Disabling THP..."
echo never > /sys/kernel/mm/transparent_hugepage/enabled

ok "Setting up tcmallog..."
export TCMALLOC_NORELEASE=1
source ../env/tcmalloc.env
export LD_PRELOAD=../lib/libtcmalloc_minimal.so

ok "Disabling defrag..."
source ../env/disable_defrag.env

ok "Disabling ASLR..."
echo 0 > /proc/sys/kernel/randomize_va_space

pushd ${BASE}/benchmarks

sample bfs ./bfs -f ./fr.el -n 20
sample gups ./gups 32
sample hashjoin ./hashjoin
sample svm ./train ./kdd12
sample btree ./BTree
sample xsbench ./XSBench -s XL -t 1 -l 128
sample canneal ./canneal 1 15000 2000 ./canneal.inp 6000
sample ./astar ./BigLakes2048.cfg
sample ./omnetpp ./omnetpp.ini
sample ./streamcluster 10 20 128 1000000 200000 5000 none ./output.txt 1

#sample ${cycles} sssp ./sssp -f ./pr-kron.wsg -n 1
#sample ${cycles} dedup ./dedup -cpt3 -i ./fr.csv -o /dev/shm/out.ddp
#sample ${cycles} pr ./pr -f ./fr.el -n 2 -i 10

popd
