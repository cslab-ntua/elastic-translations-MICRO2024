#!/bin/bash
# FIXME: this needs review / cleanup
# Env variable tunables:
# - NODE: NUMA node
# - BASE: Path 'root' folder
# - PGSZ: pte (4K), ptec (64K), thp (2M), pmd (2M), pmdc (32M), pud (1G)
# - MEM: Memory in GB for htlb reservation
# - SUFFIX: suffix identifier for the results out file
# - LD_PRELOAD: preload libraries (e.g. tcmalloc)
# - ALLOCATORS: jemalloc, tcmalloc, tcmallog-gperf, temeraire
# - BENCHMARKS: specify list of benchmarks to run
# - OMP_NUM_THREADS: Number of OpenMP threds
# - PERF_EVENTS: list of perf events to trace
# - ITER: times to run each benchmark
# - TASKSET_CORE: taskset core
# - HWK: Enable HawkEye
# - ETHEAP: Enable ETHEAP
# - LESHY: Enable Leshy for coverage target $LESHY
# - MODE: Only used for Trident (FIXME: )
# - TYPE: [host|vm]
# - FRAG_TARGET: 0-100, target fragmetnation index (fmfi)
# - KHUGE: enable or disable khugepaged
# - ETONLINE: whether to run online leshy
# - OLESHY: run the WIP Rust-based online leshy
# - PRCTL: prctl prefix (prctl controls ET modes, hint loading, etc.)

ok() {
	echo -e "[\033[0;32mOK\033[0m] ${@}"
}

fail() {
	echo -e "[\033[0;31mFAILED\033[0m] ${@}"
	exit 1
}

check() {
	[ $# -eq 2 -o $# -eq 3 ] || fail "internal: invalid check args"
	cmd="${1}"
	msg="${2}"
	[ -z ${3} ] && fmsg="${msg}"

	eval ${cmd} && ok "${msg}" || fail "${fmsg}"
}

set_cpufreq() {
	[ ! $# -eq 3 ] && fail "internal: invalid set_cpufreq args"

	if [ "${MODE}" == "trident" ]; then
		ok "Skipping cpufreq for trident..."
		return
	fi

	if [ ! -z "$(lscpu | grep -i qemu)" ]; then
		ok "Skpping cpufreq, virtualized run..."
		return
	fi

	minf="${1}"
	maxf="${2}"
	gov="${3}"

	cpus=$(numactl --hardware | grep "node $NODE cpus:" | cut -f 2 -d ':')
	for cpu in $cpus; do
		cpufreq-set -d "${minf}" -u "${maxf}" -g "${gov}" -c "${cpu}" || fail "Failed to set cpufreq for ${cpu}"
	done
}

cleanup() {
	if [[ $(pgrep -cf "./run.sh") -gt 1 ]]; then
		echo "Skipping cleanup, another run ongoing..."
		return
	fi

	echo "Cleaning up before exiting..."
	if [[ ${TYPE} == "host" ]]; then
		check "set_cpufreq 1000MHz 3GHz performance" "Restoring cpufreq..."
	fi
	check "echo 0 > /proc/sys/vm/overcommit_memory" "Restoring overcommit..."
	unset LD_PRELOAD
	for size in 64 $(( 2 << 10 )) $(( 32 << 10 )) $(( 1 << 20 )); do
		ok "Releasing $size htlb-sized pages..."
		echo 0 > ${NODE_SYSFS}/hugepages/hugepages-${size}kB/nr_hugepages || true
	done

	pgrep -g0 memfrag &>/dev/null && pkill -eg0 -TERM memfrag &>/dev/null

	# FIXME: this needs cleanup
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

	ok "Unmounting /dev/hugepages"
	sleep 1
	umount /dev/hugepages &>/dev/null;
	sleep 1
	umount /dev/hugepages &>/dev/null;
	ok "Unsetting GLIBC_TUNABLES"
	unset GLIBC_TUNABLES

	if [[ -f /proc/coalapaging/hints_active ]]; then
		hints_active=$(cat /proc/coalapaging/hints_active)
		if [[ "${hints_active}" -ne 0 ]]; then
			check "echo 0 > /proc/coalapaging/hints_active" "hints_active nonzero, clearing..."
		fi
	fi

	[ -f "${BASE}/benchmarks/out.ddp" ] && rm "${BASE}/benchmarks/out.ddp"

	ok "Restoring defrag..."
	source ${BASE}/env/enable_defrag.env
}

[ -z ${TYPE} ] && export TYPE="host"
source ${BASE}/env/base.env

export STARTENV="$(env)"

[ -z ${NODE} ] && NODE=0
export NODE
export NODE_SYSFS="/sys/devices/system/node/node${NODE}"

export RESULTS="${BASE}/results/${TYPE}/${RESULTS:-}"
mkdir -p ${RESULTS}

trap cleanup EXIT

if [[ ${TYPE} == "host" ]]; then
	check "set_cpufreq 2.7GHz 2.7GHz userspace" "Setting cpufreq..."
fi

check "echo 1 > /proc/sys/vm/overcommit_memory" "Setting overcommit..."
check "echo 1000000 > /proc/sys/vm/max_map_count" "Setting max_map_count..."
check "echo 0 > /proc/sys/kernel/randomize_va_space" "Disabling ASLR..."

[ -z ${MEM} ] && MEM=90
export MEM
export MEMKB=$(( ${MEM} << 20 ))

nr_hptec=0
nr_hpmd=0
nr_hpmdc=0
nr_hpud=0

pgsz=$(getconf PAGESIZE)
pgszkb=$(( ${pgsz} >> 10 ))
[ ${pgszkb} -eq 4 -o ${pgszkb} -eq 16 -o ${pgszkb} -eq 64 ] || fail "invalid page size: ${pgsz}"

hpmdszkb=$(( $(cat /sys/kernel/mm/transparent_hugepage/hpage_pmd_size) >> 10 ))

if [ ${pgszkb} -eq 4 ]; then
	hptecszkb=64
	hpmdcszkb=$(( ${hpmdszkb} * 16 ))
	hpudszkb=$(( 1 << 20 ))
else
	hptecszkb=$(( 2 * 1024 ))
	hpmdcszkb=$(( ${hpmdszkb} * 32 ))
fi

ok "pgsz: ${pgszkb}KB, hptecsz: ${hptecszkb}KB, hpmdsz: ${hpmdszkb}KB, hpmdcsz: ${hpmdcszkb}KB, hpudsize: ${hpudszkb}KB"

export SUFFIX=".${pgszkb}KB"

case "${PGSZ}" in
	"pte")
		check "echo never > /sys/kernel/mm/transparent_hugepage/enabled" "Disabling THP..."
		ok "Disabling mTHP"
		if [[ -f "/sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled" ]]; then
			echo never > /sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled
			echo never > /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/enabled
		fi
		unset glibcszkb
		unset TCMALLOC_HTLB_SIZE_KB
		export SUFFIX="${SUFFIX}.base"
		;;
	"mthp")
		check "echo never > /sys/kernel/mm/transparent_hugepage/enabled" "Disabling THP..."
		check "echo never > /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/enabled" "Enabling mTHP..."
		check "echo always > /sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled" "Enabling mTHP..."
		unset glibcszkb
		unset TCMALLOC_HTLB_SIZE_KB
		export SUFFIX="${SUFFIX}.mthp"
		;;
	"thp-mthp")
		check "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "Enabling THP..."
		check "echo always > /sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled" "Enabling mTHP..."
		check "echo always > /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/enabled" "Enabling mTHP..."
		unset glibcszkb
		unset TCMALLOC_HTLB_SIZE_KB
		export SUFFIX="${SUFFIX}.thp-mthp"
		;;
	"thp")
		check "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "Enabling THP..."
		ok "Disabling mTHP"
		if [[ -f "/sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled" ]]; then
			echo never > /sys/kernel/mm/transparent_hugepage/hugepages-64kB/enabled
			echo always > /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/enabled
		fi
		unset glibcszkb
		unset TCMALLOC_HTLB_SIZE_KB
		export SUFFIX="${SUFFIX}.thp"
		;;
	"hptec")
		[ ! -z ${PRCTL} ] && fail "tcr and htlb are mutually exclusive"
		check "echo never > /sys/kernel/mm/transparent_hugepage/enabled" "Disabling THP..."
		nr_hptec=$(( ${MEMKB} / ${hptecszkb} ))
		glibcszkb=${hptecszkb}
		export TCMALLOC_HTLB_SIZE_KB=${hptecszkb}
		export SUFFIX="${SUFFIX}.hptec"
		;; 
	"hpmd")
		[ ! -z ${PRCTL} ] && fail "tcr and htlb are mutually exclusive"
		check "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "Enabling THP..."
		nr_hpmd=$(( ${MEMKB} / ${hpmdszkb} ))
		glibcszkb=${hpmdszkb}
		export TCMALLOC_HTLB_SIZE_KB=${hpmdszkb}
		export SUFFIX="${SUFFIX}.hpmd"
		;; 
	"hpmdc")
		[ ! -z ${PRCTL} ] && fail "tcr and htlb are mutually exclusive"
		check "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "Enabling THP..."
		nr_hpmdc=$(( ${MEMKB} / ${hpmdcszkb} ))
		glibcszkb=${hpmdcszkb}
		export TCMALLOC_HTLB_SIZE_KB=${hpmdcszkb}
		export SUFFIX="${SUFFIX}.hpmdc"
		;;
	"hpud")
		[ ! -z ${PRCTL} ] && fail "tcr and htlb are mutually exclusive"
		[ ! $pgszkb -eq 4 ] && fail "pagesize doesn't support PUDs"
		check "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "Enabling THP..."
		nr_hpud=$(( ${MEMKB} / ${hpudszkb} ))
		glibcszkb=${hpudszkb}
		export TCMALLOC_HTLB_SIZE_KB=${hpudszkb}
		export SUFFIX="${SUFFIX}.hpud"
		export hpud=1
		;;
esac

if [[ -n ${glibcszkb} && -z ${MALLOC} ]]; then
	export GLIBC_TUNABLES=glibc.malloc.hugetlb=$(( ${glibcszkb} << 10 ))
	ok "Setting GLIBC_TUNABLES=${GLIBC_TUNABLES}..."
fi

if [[ ${TYPE} == "host" && "${MODE}" != "trident" ]]; then
	[ ${nr_hptec} -eq 0 ] && check "echo ${nr_hptec} > ${NODE_SYSFS}/hugepages/hugepages-${hptecszkb}kB/nr_hugepages" "Reserving ${nr_hptec} contig-pte pages..."
	[ ${nr_hpmd} -eq 0 ] && check "echo ${nr_hpmd} > ${NODE_SYSFS}/hugepages/hugepages-${hpmdszkb}kB/nr_hugepages" "Reserving ${nr_hpmd} hpmd pages..."
	[ ${nr_hpmdc} -eq 0 ] && check "echo ${nr_hpmdc} > ${NODE_SYSFS}/hugepages/hugepages-${hpmdcszkb}kB/nr_hugepages" "Reserving ${nr_hpmdc} contig-pmd pages..."
	[ ${pgszkb} -eq 4 -a ${nr_hpud} -eq 0 ] && check "echo ${nr_hpud} > ${NODE_SYSFS}/hugepages/hugepages-${hpudszkb}kB/nr_hugepages" "Reserving ${nr_hpud} hpud pages..."

	[ ${nr_hptec} -gt 0 ] && check "echo ${nr_hptec} > ${NODE_SYSFS}/hugepages/hugepages-${hptecszkb}kB/nr_hugepages" "Reserving ${nr_hptec} contig-pte pages..."
	[ ${nr_hpmd} -gt 0 ] && check "echo ${nr_hpmd} > ${NODE_SYSFS}/hugepages/hugepages-${hpmdszkb}kB/nr_hugepages" "Reserving ${nr_hpmd} hpmd pages..."
	[ ${nr_hpmdc} -gt 0 ] && check "echo ${nr_hpmdc} > ${NODE_SYSFS}/hugepages/hugepages-${hpmdcszkb}kB/nr_hugepages" "Reserving ${nr_hpmdc} contig-pmd  pages..."
	[ ${pgszkb} -eq 4 -a ${nr_hpud} -gt 0 ] && check "echo ${nr_hpud} > ${NODE_SYSFS}/hugepages/hugepages-${hpudszkb}kB/nr_hugepages" "Reserving ${nr_hpud} hpud pages..."
fi

[ ! -z ${MALLOC} ] && export SUFFIX="${SUFFIX}.${MALLOC}"
# FIXME: we only use tcmalloc-norelease atm
case "${MALLOC}" in
	"jemalloc")
		export LD_PRELOAD="${BASE}/lib/jemalloc.so:${LD_PRELOAD}"
		;;
	"tcmalloc")
		export LD_PRELOAD="${BASE}/lib/libtcmalloc_minimal.so:${LD_PRELOAD}"
		unset TCMALLOC_NORELEASE
		source ${BASE}/env/tcmalloc.env
		;;
	"tcmalloc-norelease")
		export LD_PRELOAD="${BASE}/lib/libtcmalloc_minimal.so:${LD_PRELOAD}"
		export TCMALLOC_NORELEASE=1
		source ${BASE}/env/tcmalloc.env
		;;
	"temeraire")
		export LD_PRELOAD="${BASE}/lib/temeraire.so:${LD_PRELOAD}"
		;;
	"tcmalloc-gperf")
		export LD_PRELOAD="${BASE}/lib/tcmalloc-gperf.so:${LD_PRELOAD}"
		;;
	*)
		unset LD_PRELOAD
esac

[ ! -z ${LD_PRELOAD} ] && ok "Preloading ${LD_PRELOAD}..."
[ ! -z ${SUFFIX} ] && ok "Setting SUFFIX=${SUFFIX}..."

[ -z ${PERF_EVENTS} ] && PERF_EVENTS="cycles,page-faults,dtlb_walk,l2d_tlb,itlb_walk,task-clock"
export PERF_EVENTS
ok "Tracing ${PERF_EVENTS}..."

export NUMA_PREFIX="numactl -N${NODE} -m${NODE}"
ok "Running on node ${NODE}..."

if [ -z ${TASKSET_CORE} ]; then
	CPUS=$(numactl -H | grep "node ${NODE} cpus" | cut -f 2 -d ':')
	read -r -a CPU_ARR <<< "$CPUS"
	TASKSET_CORE="${CPU_ARR[$(( $RANDOM % ${#CPU_ARR[@]} ))]}"
fi
export TASKSET_PREFIX="taskset -c ${TASKSET_CORE}"

export PERF_PREFIX="perf stat -e ${PERF_EVENTS}"
export PREFIX="${NUMA_PREFIX} ${PERF_PREFIX}"

# OMP threads
[ -z ${OMP_NUM_THREADS} ] && export OMP_NUM_THREADS=1
ok "Running with $OMP_NUM_THREADS threads"

export ALL_BENCHMARKS="submission"
[ -z "${BENCHMARKS}" ] && BENCHMARKS=${ALL_BENCHMARKS}
export BENCHMARKS
ok "Running the following workloads: ${BENCHMARKS}"

# save run config / env
save_config() {
	CONFIG="${1}/config${SUFFIX}"
	if [ -f "${CONFIG}" ]; then
		mv "${CONFIG}" "${CONFIG}.old"
	fi
	date &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	echo "benchmarks: ${BENCHMARKS}" &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	echo -n "thp: " &>> "${CONFIG}"
	cat /sys/kernel/mm/transparent_hugepage/enabled &>> "${CONFIG}"
	echo &>> "${CONFIG}" 

	echo -n "overcommit: " &>> "${CONFIG}"
	cat /proc/sys/vm/overcommit_memory &>> "${CONFIG}"
	echo &>> "${CONFIG}" 

	env &>> "${CONFIG}"
	echo &>> "${CONFIG}" 

	diff -uN <(echo "${STARTENV}") <(env) | rg '^[+-]' &>> "${CONFIG}"
	echo &>> "${CONFIG}" 

	echo -n "htlb: " &>> "${CONFIG}" 
	find "${NODE_SYSFS}/hugepages/" -type f -iname "nr_hugepages" -exec cat '{}' + &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	numactl -H | grep free &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	numastat &>> "${CONFIG}"  &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	cat /proc/vmstat &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	cat /proc/meminfo &>> "${CONFIG}" 
	echo &>> "${CONFIG}" 

	sysctl -a &>> "${CONFIG}"
	echo &>> "${CONFIG}" 

	fmfi.py -a &>> "${CONFIG}"
	echo &>> "${CONFIG}" 


	journalctl -kb0 -n10 &>> "${CONFIG}"
	echo &>> "${CONFIG}" 
}

get_fmfi() {
	echo $(fmfi.py  | grep 'Order.*9 FMFI'  | cut -f 2 -d ':' | tr -d ' %' | cut -f 1 -d '.')
}

wait_frag() {
	pid=$(pgrep memfrag | sort -u | tail -n1)
	status=$(cat /proc/${pid}/stat | cut -f 3 -d ' ')
	until [ "${status}" == "S" ]; do
		sleep 5
		status=$(cat /proc/${pid}/stat | cut -f 3 -d ' ')
	done
}

stats() {
	out=$1
	shift

	pid=$1
	shift

	if [[ ! -z "${pid}" ]]; then
		ok "Running pagecollect..."
		pagecollect "${pid}" &>> "${out}"
		echo "pid stats: " &>> "${out}"
		echo "$(cat /proc/${pid}/status)" &>> "${out}"
		echo "$(cat /proc/${pid}/smaps)" &>> "${out}"
		echo &>> "${out}"

		if [[ ! -z "${MODE}" && ${TYPE} == "vm" ]]; then
			gpasend $pid
		fi
	fi

	journalctl -kb0 -n10 &>> "${out}"
	echo &>> "${out}" 

	echo "NUMA stats: " &>> "${out}"
	echo "$(numactl -H | grep free | awk '{print $4}' | tail -n1)" &>> "${out}"
	echo "$(numactl -H | grep free)" &>> "${out}"
	echo "$(numastat)" &>> "${out}"
	echo &>> "${out}"

	echo "/proc/vmstat: " &>> "${out}"
	echo "$(cat /proc/vmstat)" &>> "${out}"
	echo &>> "${out}"

	echo "/proc/meminfo" &>> "${out}"
	echo "$(cat /proc/meminfo)" &>> "${out}"
	echo &>> "${out}"

	echo "FMFI (start): " &>> "${out}"
	echo "$(fmfi.py)" &>> "${out}"
	echo &>> "${out}"

	echo "Buddyinfo: " &>> "${out}"
	echo "$(cat /proc/buddyinfo)" &>> "${out}"
	echo "$(cat /proc/pagetypeinfo)" &>> "${out}"
	echo &>> "${out}"

	echo "Khugecollapsed: " &>> "${out}"
	echo "$(cat /sys/kernel/mm/transparent_hugepage/khugepaged/pages_collapsed)" &>> "${out}"
	echo &>> "${out}"

	if [[ -d /proc/coalapaging ]]; then
		echo "Coalacollapsed: " &>> "${out}"
		echo "$(cat /proc/coalapaging/migrated_pages)" &>> "${out}"
		echo &>> "${out}"
	fi

	echo "Status: " &>> "${out}"
	echo "$(status.sh)" &>> "${out}"
	echo &>> "${out}"

	if [[ -f /proc/coalapaging/contmap ]]; then
		echo "contmap: " &>> "${out}"
		echo "$(cat /proc/coalapaging/contmap)" &>> "${out}"
		echo &>> "${out}"
		echo "$(parse_contmap.py)" &>> "${out}"
		echo &>> "${out}"
		echo "$(cat /proc/coalapaging/buddyinfo)" &>> "${out}"
		echo &>> "${out}"
	fi
}

run() {
	iter=$i
	shift

	group="${@: -1}"
	[ $# -eq 4 ] && benchmark="${3}" || benchmark=${group}

	# Check if the benchmark or the benchmark group are enabled
	if ! echo "${BENCHMARKS}" | grep -Eqsw "${benchmark}|${group}"; then
		ok "Skipping benchmark ${benchmark}..."
		return
	fi

	if [[ -f "/proc/coalapaging/hints_active" ]]; then
		hints_active=$(cat /proc/coalapaging/hints_active)
		if [[ "${hints_active}" -ne 0 ]]; then
			check "echo 0 > /proc/coalapaging/hints_active" "Clearing hints_active"
		fi
	fi

	ok "Running ${benchmark}, iteration ${iter}..."

	if [[ -z "${MULTI}" && $(pgrep -cf "./run.sh") -eq 1 ]]; then 
		check "echo 3 > /proc/sys/vm/drop_caches" "Dropping caches..."

		if [ ! -z "${FRAG_TARGET}" ]; then
			ok "Fragmenting node to ${FRAG_TARGET}%"

			pgrep memfrag &>/dev/null && pkill -9 -eg0 memfrag
			sleep 5

			source ${BASE}/env/disable_defrag.env

			export FRAG_TARGET
			frag.sh ${benchmark} &

			sleep 10
			wait_frag
			fmfi.py
		fi
	fi

	if [ -z "${KHUGE}" ]; then
		check "source ${BASE}/env/disable_defrag.env" "Disabling khugeapged..."
	else
		check "source ${BASE}/env/enable_defrag.env" "Enabling khugepaged..."
	fi

	source "${BASE}/env/dyndbg.env"

	pushd "${BASE}/${1}"

	outdir="${RESULTS}/${3}${SUFFIX}${EXTRA}"
	if [ -d "${outdir}" ]; then
		#cp -r "${outdir}" "${outdir}.$(date +%s)"
		mv "${outdir}" "${outdir}.$(date +%s)"
	fi
	mkdir -p "${outdir}"

	out="${outdir}/${iter}"
	rm -f "${out}"

	export TRIGGER="/dev/shm/${benchmark}"
	check "touch ${TRIGGER}" "Creating inotify trigger file ${TRIGGER}..."

	if [[ "${benchmark}" == "redis" || "${benchmark}" == "memcached" || ${benchmark} == "mongo" ]]; then
		export PREFIX
		export TASKSET_CORE
		export TRIGGER
		cmd="${2}"
	else
		cmd="${PREFIX} ${2}"
	fi

	if [ $iter -eq 1 ]; then
		save_config "${outdir}"
	fi
	ok "${cmd} >> ${out}"

	echo "${cmd} >> ${out}" &>> "${out}"
	date &>> "${out}"
	echo &>> "${out}"

	stats "${out}"

	if [[ ! -z "${ETONLINE}" ]]; then
		numactl -N1 -m1 epochs.sh "${benchmark}" 1024 5 "${out}.traces" &>> "${out}.leshy.out" &
		#numactl -N1 -m1 epochs.sh "${benchmark}" 1024 15 "${out}.traces" &>> "${out}.leshy.out" &
	fi
	
	#if [[ "${benchmark}" == "btree" || "${name}" == "gups" ]]; then
	#	unset LD_PRELOAD
	#fi

	{ eval ${cmd} 2>&1 | tee -a "${out}"; echo 1 >> "${TRIGGER}"; } &
	subproc=$!
	bin=$(echo $2 | awk '{print $1}')
	check "sleep 10" "Waiting for ${bin} to spawn..."

	if [[ "${benchmark}" == "redis" ]]; then
		pid=$(pgrep -fg0 "valkey-server")
	elif [[ "${benchmark}" == "memcached" ]]; then
		pid=$(pgrep -fxg0 "^.*memcached .*" )
	elif [[ "${benchmark}" == "mongo" ]]; then
		pid=$(pgrep -fxg0 "^mongod.*" )
	else
		pid=$(pgrep -fx ^$bin.*)
	fi
	check "echo -1000 > /proc/${pid}/oom_score_adj" "Lowering oom score..."

	if [ ! -z "${HWK}" ]; then
		export HWK
		[ ! -z "${HWK_TRACE}" ] && export HWK_TRACE
		[ ! -z "${HWK_THP}" ] && export HWK_THP
		${PRCTL} ${pid}
	fi

	if [ ! -z "${OLESHY}" ]; then
		ok "Spawning oleshy for ${pid}..."
		oleshy ${pid} &
	fi

	check "inotifywait -qq -e modify ${TRIGGER}" "Waiting for trigger..."
	ok "Killing leshy..."
	pkill -TERM -eg0 epochs || true
	ok "Taking snapshot..."
	stats ${out} ${pid} 
	ok "Resuming workload..."
	if [[ "${benchmark}" == "redis" || "${benchmark}" == "memcached" || "${benchmark}" == "mongo" ]]; then
		kill -KILL ${pid}
	else
		kill -USR1 ${pid}
	fi

	wait ${subproc}

	ok "Done..."

	if [[ $(pgrep -cf "./run.sh") -gt 1 ]]; then
		echo "Skipping cleanup, another run ongoing..."
		return
	else
		ok "Killing memfrag..."
		pkill -9 -eg0 memfrag &>/dev/null
	fi

	sleep 5

	if [[ -f "/proc/coalapaging/hints_active" ]]; then
		hints_active=$(cat /proc/coalapaging/hints_active)
		if [[ "${hints_active}" -ne 0 ]]; then
			check "echo 0 > /proc/coalapaging/hints_active" "Clearing hints_active"
		fi
	fi

	popd
}

export TCRPERF=1
export PREFIX="${NUMA_PREFIX} ${TASKSET_PREFIX} ${PRCTL}"
if [ ! -z ${LESHY} ]; then
	export LESHY=1
	export TARGET=${TARGET}
	if [ ! -z ${ACCESSBIT} ]; then
		export ACCESSBIT
	fi
	if [ ! -z ${NOET} ]; then
		export NOET
	fi
fi

if [ ! -z ${ETHEAP} ]; then
	export ETHEAP
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
fi

for i in $(seq $ITER); do
	run $i benchmarks "./valkey.sh" redis submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./memcached.sh" memcached submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./hashjoin" hashjoin submission
done

for i in $(seq $ITER); do
	DATA_PREFIX=.
	#[ ${TYPE} == "vm" ] && DATA_PREFIX=/root
	run $i benchmarks "./train ${DATA_PREFIX}/kdd12" svm submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./BTree" btree submission
done

for i in $(seq $ITER); do
	#run $i benchmarks "./gups 64" gups submission
	run $i benchmarks "./gups 32" gups submission
done

for i in $(seq $ITER); do
	#run $i benchmarks "./XSBench -s XL -t 32 -l 170" xsbench submission
	#run $i benchmarks "./XSBench -s XL -t 1 -l 450" xsbench submission
	run $i benchmarks "./XSBench -s XL -t 1 -l 128" xsbench submission
done

for i in $(seq $ITER); do
	#run $i benchmarks "./pr -g 28 -n 1 -i 5" pr submission
	run $i benchmarks "./pr -f ./fr.el -n 2 -i 10" pr submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./cc -f ./fr.el -n 20" cc submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./bfs -f ./fr.el -n 20" bfs submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./sssp -f ./pr-kron.wsg -n 1" sssp submission
done

for i in $(seq $ITER); do
	run $i benchmarks './daphne --select-matrix-repr ./pagerank.daph G=\"./fr.csv\" alpha=0.85 maxiter=20' daphne submission
	#run $i benchmarks './daphne --select-matrix-repr ./pagerank.daph G=\"/mnt/nvme0n1p2/synthetic.csv\" alpha=0.85 maxiter=1' daphne submission
done

export PREFIX="${NUMA_PREFIX} ${PRCTL}"
for i in $(seq $ITER); do
	run $i benchmarks "./dedup -cpt3 -i ./fr.csv -o /dev/shm/out.ddp" dedup submission
done

for i in $(seq $ITER); do
	#run $i benchmarks "./graph500 -s 26 -e 30" graph500 submission
	run $i benchmarks "./graph500 -s 27 -e 30 -o g5.el -r g5.r" graph500 submission
done

export PREFIX="${NUMA_PREFIX} ${PERF_PREFIX} ${PRCTL}"
for i in $(seq $ITER); do
	run $i benchmarks "./llama-cli -m /mnt/nvme0n1p2/home/stratos/datasets/llama70b.gguf -t 32  -p 'Whats in a TLB?'" llama submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./ymongo.sh" mongo submission
done

export PREFIX="${NUMA_PREFIX} ${TASKSET_PREFIX} ${PERF_PREFIX} ${PRCTL}"

for i in $(seq $ITER); do
	DATA_PREFIX=.
	#[ ${TYPE} == "vm" ] && DATA_PREFIX=/root
	run $i benchmarks "./canneal 1 15000 2000 ${DATA_PREFIX}/canneal.inp 6000" canneal submission
done

if [ ! -z ${ETHEAP} ]; then
	export ETHEAP
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

for i in $(seq $ITER); do
	run $i benchmarks "./astar ./BigLakes2048.cfg" astar submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./omnetpp ./omnetpp.ini" omnetpp submission
done

for i in $(seq $ITER); do
	run $i benchmarks "./streamcluster 10 20 128 1000000 200000 5000 none ./output.txt 1" streamcluster submission
done

# FIXME: MULTI used to toggle multi-programmed execution, but it's not used anymore
[ ! -z "${MULTI}" ] && sleep 36000

exit 0
