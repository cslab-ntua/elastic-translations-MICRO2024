#!/bin/bash

[ ! -z "${HWK_THP}" ] && export HWK_THP
[ ! -z "${HWK_SLEEP}" ] && export HWK_SLEEP

enable_khuge() {
	[ -z "${COALA_KHUGE}" ] && return

	sleep 10
	echo "prctl --khuge --hints ${1} $(pgrep -f "^${2}")"
	if [ ! -z "${NOET}" ]; then
		prctl --khuge --only2m --hints "${1}" "$(pgrep -f "^${2}")"
	else
		prctl --khuge --hints "${1}" "$(pgrep -f "^${2}")"
	fi
}

case ${1} in
	*hashjoin*)
		export BENCHMARK="hashjoin"
		export CMD="hashjoin"
		;;
	*train*)
		export BENCHMARK="svm"
		export CMD="train"
		;;
	*canneal*)
		export BENCHMARK="canneal"
		export CMD="canneal"
		;;
	*astar*)
		export BENCHMARK="astar"
		export CMD="astar"
		;;
	*omnetpp*)
		export BENCHMARK="omnetpp"
		export CMD="omnetpp"
		;;
	*streamcluster*)
		export BENCHMARK="streamcluster"
		export CMD="streamcluster"
		;;
	*XSBench*)
		export BENCHMARK="xsbench"
		export CMD="XSBench"
		;;
	*graph500*)
		export BENCHMARK="graph500"
		export CMD="graph500"
		;;
	*BTree*)
		export BENCHMARK="btree"
		export CMD="BTree"
		;;
	*gups*)
		export BENCHMARK="gups"
		export CMD="gups"
		;;
	*pr*)
		export BENCHMARK="pr"
		export CMD="pr"
		;;
	*bfs*)
		export BENCHMARK="bfs"
		export CMD="bfs"
		;;
	*sssp*)
		export BENCHMARK="sssp"
		export CMD="sssp"
		;;
esac

if [ ! -z "${LESHY}" ]; then
	source ${BASE}/env/coala.env
	source ${BASE}/env/et.env

	hints_prefix="${BASE}/traces/${HINTS:-leshy}/${TARGET}/${BENCHMARK}"

	if [ ! -z "${NOET}" ]; then
		if [ ! -z "${ACCESSBIT}" ]; then
			enable_khuge "${hints_prefix}.accessbit.hints" ${1} &
			prctl --ca --only2m --hints "${hints_prefix}.accessbit.hints" -- "${@}"
		else
			enable_khuge "${hints_prefix}.hints" ${1} &
			prctl --ca --only2m --hints "${hints_prefix}.hints" -- "${@}"
		fi
	else
		if [ ! -z "${ACCESSBIT}" ]; then
			enable_khuge "${hints_prefix}.accessbit.hints" ${1} &
			prctl --ca --et --hints "${hints_prefix}.accessbit.hints" -- "${@}"
		else
			enable_khuge "${hints_prefix}.hints" ${1} &
			prctl --ca --et --hints "${hints_prefix}.hints" -- "${@}"
		fi
	fi
elif [ ! -z "${NOET}" ]; then
	source ${BASE}/env/coala.env
	prctl --ca -only2m -- "${@}"
elif [ ! -z "${HWK}" ]; then
	source ${BASE}/env/hwk.env
	prctl --hwk -- "${@}"
elif [ ! -z "${ETHEAP}" ]; then
	source ${BASE}/env/coala.env
	source ${BASE}/env/et.env
	case ${cmd} in
		astar|omnetpp|streamcluster)
			if [ ! -z "${PRCTL_THP}" ]; then
				echo "Disabling THP..."
				echo never > /sys/kernel/mm/transparent_hugepage/enabled
			fi
			;;
	esac
	echo "Enabling greedy ET..."
	prctl --ca --et -- "${@}"
elif [ ! -z "${TRIDENT}" ]; then
	export CONFIG="TRIDENT"
	# FIXME: include the trident artifact as a submodule in the repo
	source ${BASE}/src/trident/Trident-MICRO21-artifact/scripts/common.sh
	cleanup_system_configs
	setup_4kb_configs
	drop_caches
	prepare_system_configs
fi
