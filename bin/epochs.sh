#!/bin/bash

source $(dirname ${0})/scripts/common.sh
export PERF="$(dirname ${0})/bin/perf"

usage() {
	>&2 echo "$(basename $0) <benchmark> <sampling_interval> <leshy_interval> <outdir>"
	exit 1
}

ok() {
	echo -e "[\033[0;32mOK\033[0m] ${@}"
}

profile() {
	snapshot=$1

	start_time=$(date +%s%3N)

	DUMP=1 perf report --quiet --stdio \
		-i "${outdir}/${benchmark}.raw.${snapshot}" > \
		"${outdir}/${benchmark}.dump.${snapshot}"

	end_time=$(date +%s%3N)

	ok "Parsed raw perf data in $(( end_time - start_time ))ms"

	start_time=$(date +%s%3N)

	#first=$(( ${snapshot} - 6 ))
	first=$(( ${snapshot} - 1 ))
	if [[ "${first}" -lt 0 ]]; then
		first=0
	fi

	prev=$(( ${snapshot} - 1 ))
	if [[ "${prev}" -lt 0 ]]; then
		prev=0
	fi
	
	for i in $(seq $snapshot -1 $first); do
#		if [[ "${i}" -ge "${prev}" && ! -s "${outdir}/${benchmark}.dump.${i}" ]]; then
#			echo "latest misses empty, skipping..."
#			return
#		fi
		cat "${outdir}/${benchmark}.dump.${i}" >> "${outdir}/${benchmark}.epoch.${snapshot}"
	done

	if [[ ! -s "${outdir}/${benchmark}.epoch.${snapshot}" ]]; then
		echo "misses empty, skipping..."
		return
	fi

	# FIXME: configurable slacks per benchmark?
	leshyv3 "${outdir}/${benchmark}.epoch.${snapshot}" \
		"${outdir}/${benchmark}.hints.${snapshot}.full" 100000 70

	if [[ ! -s "${outdir}/${benchmark}.hints.${snapshot}.full" ]]; then
		echo "hints empty, skipping..."
		return
	fi

	#if [[ ! -s "${outdir}/${benchmark}.hints.${prev}.full" ]]; then
	#	echo "prev hints empty, skipping..."
	#	return
	#fi

	#head -n16 "${outdir}/${benchmark}.hints.${snapshot}.full" > \
	#	"${outdir}/${benchmark}.hints.${snapshot}"

	count=0
	loops=0
	while read -r line; do
		if [[ ${benchmark} == "train" && ${loops} -lt 4 ]]; then
			loops=$(( ${loops} + 1 ))
			echo "skipping first hints for svm..."
			continue;
		fi
		size=$(echo $line | gawk --non-decimal-data -F '-' '{print $2 - $1}')
		size=$(( ${size} >> 12 ))
		if [[ "${size}" -eq 1 ]]; then
			continue;
		fi
		count=$(( ${count} + ${size} ))
		if [[ "${count}" -gt "${nrpages}" ]]; then
			break;
		fi
		#ok "Adding hint of size ${size} (${count} / ${nrpages})..."
		echo "${line}" >> "${outdir}/${benchmark}.hints.${snapshot}"
	done < "${outdir}/${benchmark}.hints.${snapshot}.full"

	end_time=$(date +%s%3N)

	ok "Generated hints in $(( end_time - start_time ))ms"

	if [[ ! -s "${outdir}/${benchmark}.hints.${snapshot}" ]]; then
		echo "WTFWTF Hints empty, skipping..."
		return
	fi

	if [[ "${snapshot}" -ne 0 ]]; then
		prev=$(( ${snapshot} - 1 ))

		current=$(sha256sum ${outdir}/${benchmark}.hints.${snapshot} | awk '{print $1}')
		prev=$(sha256sum ${outdir}/${benchmark}.hints.${prev} | awk '{print $1}')

		if [[ "${current}" == "${prev}" ]]; then
			echo "Hints same, skipping..."
			return
		fi
	fi

#	diff=$(( $end_time - $start_time ))
#	if [[ $diff -gt 6000 ]]; then
#		echo "took too long skipping"
#		return
#	fi

	flock -x -n 200 || return;
	
	if [[ "${snapshot}" -lt $(cat ./.lockfile) ]]; then
		echo "wtf"
		flock -u 200
		return;
	fi

	start_time=$(date +%s%3N)

	echo "${snapshot}" > ./.lockfile
	#pkill -9 'online_leshy512$' || true
	pkill -9 'leshyv3$' || true

	#echo 0 > /sys/module/coalapaging/parameters/khugepaged
	echo 1 > "/proc/${pid}/coala_hints"
	echo 1 > /sys/module/coalapaging/parameters/khugepaged

#	if pgrep -f '--khuge' &>/dev/null; then
#		echo "not finished wtf"
#		return
#	fi

	if [[ ! -z "${NOET}" ]]; then
		export LESHYDBG=1
		prctl --ca --only2m --hints "${outdir}/${benchmark}.hints.${snapshot}" ${pid}
		prctl --khuge --only2m --hints "${outdir}/${benchmark}.hints.${snapshot}" ${pid}
	else
		prctl --ca --et \
			--hints "${outdir}/${benchmark}.hints.${snapshot}" ${pid}
		prctl --khuge \
			--hints "${outdir}/${benchmark}.hints.${snapshot}" ${pid}
	fi

	#echo 1 > /sys/module/coalapaging/parameters/khugepaged

	end_time=$(date +%s%3N)

	ok "Loaded hints in $(( end_time - start_time ))ms"

	flock -u 200
}

[ $# -ne 4 ] && usage

export benchmark=$1
case ${1} in
	*svm*)
		export benchmark="train"
		;;
	*xsbench*)
		export benchmark="XSBench"
		;;
	*btree*)
		export benchmark="BTree"
		;;
esac

export sampling_interval=$2
export leshy_interval=$3
export outdir=$4

exec 200>./.lockfile
echo 0 > ./.lockfile

echo 0 > /sys/module/coalapaging/parameters/fault_hints

mkdir -p "${outdir}"

stale="$(ls ${outdir}/${benchmark}* 2>/dev/null || echo)"
if [[ ! -z "${stale}" ]]; then
	ok "stale files from previous run, exiting..."
	echo "${stale}"
	#read -p "Press any key to proceed..."
	#rm -f ${stale}
	exit 1
fi

pid=$(pgrep "^${benchmark}$");
until [[ ! -z "${pid}" ]]; do
	echo "${benchmark} not running, retrying..."
	sleep 1

	pid=$(pgrep "^${benchmark}$");
done

export pid

#-e arm_spe/jitter=1,load_filter=1,event_filter=0x22/ \
perf record -c "${sampling_interval}" \
	-e arm_spe/jitter=1,event_filter=0x20/ \
	--no-switch-events --switch-output=signal \
	-o "${outdir}/${benchmark}" -p ${pid} &
	#-e arm_spe/jitter=1,load_filter=1,event_filter=0x20/ \ (ritred + spec)

snapshot=0

khuge_sleep=$(cat /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs)
khuge_pages=$(cat /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan)
nrpages=$(( ${khuge_pages} * ${leshy_interval} * 1000 / ${khuge_sleep} ))
nrpages=$(( 2 * ${nrpages} ))
nrpages=$(( 2 * 3 * ${nrpages} ))
ok "Total pages collapsed per leshy interval: ${nrpages}"

while pgrep "${benchmark}" &>/dev/null; do
	ok "Sleeping for ${leshy_interval}s..."
	sleep ${leshy_interval}

	ok "Taking snapshot $snapshot..."
	pkill -f -SIGUSR2 "^perf record" &>/dev/null

	ok "Processing snapshot $snapshot"
	prev="ENOENT"
	until [[ -f "${prev}" ]]; do
		prev="$(ls ${outdir}/${benchmark}.2024* 2>/dev/null || echo "ENOENT")"
	done
	
	mv "${prev}" "${outdir}/${benchmark}.raw.${snapshot}"
	profile $snapshot &
	snapshot=$(( snapshot + 1 ))
done
