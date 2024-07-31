#!/bin/bash

set -e

benchmark=${1}
mode=${2}

export FRAG_NODE=${FRAG_NODE:-0}

export FRAG_TARGET=${FRAG_TARGET:-50}
export FRAG_ORDER=${FRAG_ORDER:-9}

export FRAG_RELAX_ORDER=${FRAG_RELAX_ORDER:-13}
export FRAG_PRESS_ORDER=${FRAG_PRESS_ORDER:-7}

DEFAULT_SLACK=$(( 1 << 30 ))
export FRAG_SLACK=${FRAG_SLACK:-${DEFAULT_SLACK}}

#DEFAULT_RELEASE_SLACK=$(( 3 << 30 ))

#DEFAULT_RELEASE_SLACK=$(( 1 << 30 ))
DEFAULT_RELEASE_SLACK=0
export FRAG_RELEASE_SLACK=${FRAG_RELEASE_SLACK:-${DEFAULT_RELEASE_SLACK}}

PAGECACHE=0
case ${1} in
	*hashjoin*)
		FOOTPRINT=$(( (34500 * 2) << 20 ))
		;;
	*train*|*svm*)
		PAGECACHE=$(( 25 << 30 ))
		FOOTPRINT=$(( (19000 * 2) << 20 ))
		;;
	*canneal*)
		PAGECACHE=$(( 5 << 30 ))
		FOOTPRINT=$(( (7200 * 2) << 20 ))
		;;
	*astar*)
		FOOTPRINT=$(( (200 * 2) << 20 ))
		;;
	*omnetpp*)
		FOOTPRINT=$(( (100 * 2) << 20 ))
		;;
	*streamcluster*)
		FOOTPRINT=$(( (100 * 2) << 20 ))
		;;
	*xsbench*|*XSBench*)
		#FOOTPRINT=$(( 119 << 30 ))
		FOOTPRINT=$(( 124 << 30 ))
		#FOOTPRINT=$((125328*1024))
		;;
	*btree*|*BTree*)
		#FOOTPRINT=$(( 38 << 30 ))
		FOOTPRINT=$(( 12 << 30 ))
		#FOOTPRINT=$(( 49 << 30 ))
		#PAGECACHE=$(( 10 << 30 ))
		;;
	*gups*)
		#FOOTPRINT=$(( 66 << 30 ))
		FOOTPRINT=$(( 33 << 30 ))
		;;
	*pr*)
		FOOTPRINT=$(( 69 << 30 ))
		PAGECACHE=$(( 66 << 30 ))
		;;
	*bfs*)
		FOOTPRINT=$(( 91 << 30 ))
		PAGECACHE=$(( 32 << 30 ))
		;;
	*sssp*)
		FOOTPRINT=$(( 160 << 30 ))
		PAGECACHE=$(( 80 << 30 ))
		;;
	*graph500*)
		FOOTPRINT=$(( 48 << 30 ))
		;;
	*)
		DEFAULT_FOOTPRINT=$(( 100 << 30 ))
		FOOTPRINT=${FRAG_RELEASE:-${DEFAULT_FOOTPRINT}}
esac

echo "Fragmenting memory for ${1}, releasing $(( ${FOOTPRINT} >> 20 ))MiB"

#NR_UNFRAG=$(( $FOOTPRINT * (100 - $FRAG_TARGET) / 100 ))
RELEASE=$(( $FOOTPRINT + $PAGECACHE + $FRAG_RELEASE_SLACK ))
TOTAL=$(( $RELEASE + $FRAG_SLACK ))

export FRAG_RELEASE=${RELEASE}
if [[ "${FRAG_TARGET}" -ne 99 && "${FRAG_TARGET}" -ne 999 ]]; then
	#export FRAG_TARGET=$(( 100 - ($NR_UNFRAG * 100 / $TOTAL) ))
	export FRAG_TARGET=$(( 100 - ( (${FOOTPRINT} * (100 - ${FRAG_TARGET})) / ${TOTAL}) ))
fi

echo -1000 > /proc/self/oom_score_adj
if [[ -n "${MODE}" && "${MODE}" != "hawkeye" ]]; then
	numactl -N"${FRAG_NODE}" -m"${FRAG_NODE}" prctl --ca memfrag
elif [ ! -z "${TRIDENT}" ]; then
	numactl -N"${FRAG_NODE}" -m"${FRAG_NODE}" memfrag
elif [ "${MODE}" == "hawkeye" ]; then
	numactl -N"${FRAG_NODE}" -m"${FRAG_NODE}" memfrag
else
	if [[ -d "/sys/module/coalapaging" ]]; then
		numactl -N"${FRAG_NODE}" -m"${FRAG_NODE}" prctl --ca memfrag
	else
		numactl -N"${FRAG_NODE}" -m"${FRAG_NODE}" memfrag
	fi
fi
