#!/bin/bash

if [[ "${TYPE}" == "vm" ]]; then
	export BASE="/host"
else
	export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
fi

source "${BASE}/env/base.env"
pushd "${BASE}"

cleanup() {
	pkill -efP $$ -TERM run-benchmarks.sh
	while popd &>/dev/null; do true; done
}
trap cleanup EXIT

export NODE=${NODE:-0}
export TASKSET_CORE=${TASKSET_CORE:-0}
export MEM=${MEM:-90}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

export MALLOC=${MALLOC:-tcmalloc-norelease}

export BENCHMARKS="${BENCHMARKS:-submission}"
export ITER=${ITER:-1}

[ ! -z ${EXTRA} ] && export EXTRA=$EXTRA
[ ! -z ${PGC_DUMPVPN} ] && export PGC_DUMPVPN=$PGC_DUMPVPN

export PGSZ=${PGSZ:-thp}

unset HWK
unset TRIDENT
unset ETHEAP
unset LESHY
unset PRCTL
unset ETONLINE

[ ! -z ${MULTI} ] && export MULTI=$MULTI
[ ! -z ${ETKHUGE} ] && export ETKHUGE=$ETKHUGE
[ ! -z ${COALA_KHUGE} ] && export COALA_KHUGE=$COALA_KHUGE
[ ! -z ${KHUGE} ] && export KHUGE=$KHUGE
[ ! -z ${KHUGE_HWK} ] && export KHUGE_HWK=$KHUGE_HWK
[ ! -z ${MODE} ] && export PRCTL="${PRCTL:-prctl.sh}"

if [[ ! -z "${KHUGE_SLEEP}" ]]; then
	export KHUGE_SLEEP=$KHUGE_SLEEP
	export EXTRA=".${KHUGE_SLEEP}ms${EXTRA}"
fi

if [[ ! -z "${NOKCOMPACTD}" ]]; then
	export NOKCOMPACTD=$NOKCOMPACTD
	export EXTRA=".nokcompactd${EXTRA}"
fi

case ${MODE} in
	"hawkeye")
		[ -z "${HWK_AZ}" ] && modprobe -v asynczero &>/dev/null
		export EXTRA=".hwk${EXTRA}"
		export HWK=1
		if [ ! -z "${HWK_TRACE}" ]; then
			export HWK_TRACE
			export EXTRA=".trace${EXTRA}"
		fi
		if [ ! -z "${HWK_THP}" ]; then
			export HWK_THP
		else
			export EXTRA=".nothp${EXTRA}"
		fi
		if [ ! -z "${HWK_SLEEP}" ]; then
			export HWK_SLEEP
			export EXTRA=".$(( ${HWK_SLEEP} / 1000 ))s${EXTRA}"
		fi
		[ ! -z ${HWK_FALLBACK} ] && export HWK_FALLBACK=${HWK_FALLBACK}
		;;
	"trident")
		export EXTRA=".tr${EXTRA}"
		export TRIDENT=1
		;;
	"etheap")
		export ETHEAP=1
		export EXTRA=".etheap${EXTRA}"
		;;
	"etonline")
		export ETONLINE=1
		export ETHEAP=1
		export EXTRA=".etonline${EXTRA}"
		unset COALA_KHUGE
		;;
	"leshy")
		export LESHY=1
		export TARGET=${TARGET:-99}
		export EXTRA=".leshy${EXTRA}"

		[ ! -z ${ACCESSBIT} ] && export ACCESSBIT=${ACCESSBIT}

		if [ ! -z ${UNHINTED_FAULTS} ]; then
			export UNHINTED_FAULTS=${UNHINTED_FAULTS}
			export EXTRA=".unhinted${EXTRA}"
		fi

		if [[ ! -z "${COALA_FALLBACK}" ]]; then
			export COALA_FALLBACK=$COALA_FALLBACK
			export EXTRA=".fallback${EXTRA}"
		fi
		;;
	"leshy-thp")
		export LESHY=1
		export TARGET=${TARGET:-99}
		export EXTRA=".leshy-thp${EXTRA}"
		[ ! -z ${ACCESSBIT} ] && export ACCESSBIT=${ACCESSBIT}
		export NOET=1
		if [ ! -z ${UNHINTED_FAULTS} ]; then
			export UNHINTED_FAULTS=${UNHINTED_FAULTS}
			export EXTRA=".unhinted${EXTRA}"
		fi

		if [[ ! -z "${COALA_FALLBACK}" ]]; then
			export COALA_FALLBACK=$COALA_FALLBACK
			export EXTRA=".fallback${EXTRA}"
		fi
		;;
	"etheap-noet")
		unset ETHEAP
		unset ETONLINE
		export NOET=1
		export EXTRA=".etheap-noet${EXTRA}"
		;;
	"etonline-2m")
		export ETONLINE=1
		export ETHEAP=1
		export EXTRA=".etonline-2m${EXTRA}"
		export NOET=1
		unset COALA_KHUGE
		;;
	"oleshy")
		export OLESHY=1
		export ETHEAP=1
		export EXTRA=".oleshy${EXTRA}"
		;;
esac

run-benchmarks.sh

if [ -f /sys/kernel/debug/dynamic_debug/control ]; then
	echo -n '-p' > /sys/kernel/debug/dynamic_debug/control
fi
