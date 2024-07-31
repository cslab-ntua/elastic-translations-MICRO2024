#!/bin/bas

set -e

source $(dirname ${0})/scripts/common.sh
PROFILER="${BASE}/bin/leshy"

TRACES="${BASE}/traces"
OUTDIR="${BASE}/hints"

BENCHMARKS="xsbench btree gups graph500 pr svm hashjoin canneal astar omnetpp streamcluster"
#TARGETS="99990 100000"
TARGETS="100000"
#SLACKS="0 15 30 45 60 75 90"
#SLACKS="150"
SLACKS="100"

for s in $SLACKS; do
	for t in $TARGETS; do
		for b in $BENCHMARKS; do 
			ok "Generating hints for ${b}, target ${t}, slack ${s}..."
			${PROFILER} ${TRACES}/${b}.misses ${OUTDIR}/${t}/${b}.hints $t $s | tee ${OUTDIR}/${t}/${b}.hints.out &

			ok "Generating accessbit hints for ${b}, target ${t}, slack ${s}..."
			${PROFILER} ${TRACES}/${b}.accesses ${OUTDIR}/9999/${b}.accessbit.hints $t $s | tee ${OUTDIR}/9999/${b}.accessbit.hints.out &
		done
	done
done
wait
