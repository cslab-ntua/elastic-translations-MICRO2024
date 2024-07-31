#!/bin/bash

set -e

export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
export HINTS="${HINTS:-${BASE}/hints}"

BENCHMARKS="xsbench btree gups graph500 pr svm hashjoin canneal astar omnetpp streamcluster"
TARGETS="99990 100000"
SLACKS="0 15 30 45 60 75 90"

parse() {
	awk -F '-' '{print $2 - $1}' "${1}" | sort | uniq -c | awk '{print $0; sum += $1} END{print sum}'
}

for b in $BENCHMARKS; do 
	for t in $TARGETS; do
		for s in $SLACKS; do
			echo "hints for ${b}, target ${t}, slack ${s}: "
			parse ${DIR}/${t}/${s}/${b}.hints

			echo "accessbit hints for ${b}, target ${t}, slack ${s}: "
			parse ${DIR}/${t}/${s}/${b}.accessbit.hints
		done
	done
done
