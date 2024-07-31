#/bin/bash
# 
# Build the various components needed for the ET artifact
# 
# Set the env variable VM to build a kernel suitable for a QEMU VM
# Set the env variable KERNEL to select between different kernels:
# 	- et 
#   - et.pftrace
# 	- hwk 
#   - hwk.pftrace
# 	- vanilla
#   - vanilla.pftrace
#   - mthp
#   - trident

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

build_kernel() {
	CONFIG="./configs"

	if [[ "${KERNEL}" == "mthp" ]]; then
		pushd src/linux-mthp
		ok "Building 6.8rc-mthp kernel..."
		cp configs/* .config
	elif [[ "${KERNEL}" == "trident" ]]; then
		pushd src/

		ok "Building 4.17-trident kernel..."

		cp configs/* .config
		if [[ ! -z "${VM}" ]]; then
			CONFIG="${CONFIG}/config.vm"
		else
			CONFIG="${CONFIG}/config.altra"
		fi

		ok "Using config ${CONFIG}..."
		cp ${CONFIG} .config
	else
		pushd src/et-linux
		
		if [[ ! -z "${VM}" ]]; then
			CONFIG="${CONFIG}/vm/config.${KERNEL}"
		else
			CONFIG="${CONFIG}/native/config.${KERNEL}"
		fi

		ok "Using config ${CONFIG}..."
		cp ${CONFIG} .config
	fi

	ok "Building ${KERNEL} kernel..."
	make olddefconfig
	make prepare
	make -j$(nproc) Image.gz modules

	ok "Building perf..."
	make -j$(nproc) tools/perf

	popd
}

build_qemu() {
	pushd src/et-qemu

	mkdir -p build
	pushd build
	../configure --enable-strip --enable-trace-backends=ftrace,log --without-default-features \
		--enable-pie --enable-zstd --enable-virtfs --enable-vhost-net --enable-vhost-kernel \
		--enable-slirp --enable-numa  --enable-multiprocess --enable-membarrier \
		--enable-linux-aio --target-list=aarch64-softmmu --enable-kvm --enable-attr \
		--enable-vhost-vsock --enable-vhost-scsi --enable-tools --enable-cap-ng
	make -j$(nproc)
	popd

	popd
}

build_utils() {
	pushd src/etutils-rs

	ok "Building ET utilities and tools..."
	cargo build -r

	popd
}

build_benchmarks() {
	pushd src/benchmarks

	pushd hashjoin
	ok "Building hashjoin..."
	sh compile.sh
	popd

	pushd btree
	ok "Building btree..."
	make
	popd

	pushd gapbs
	ok "Building bfs..."
	make bfs converter
	popd

	pushd svm
	ok "Building svm..."
	make train
	popd

	pushd gups
	ok "Building gups..."
	make
	popd

	popd
}

prepare_datasets() {
	pushd src/benchmarks

	pushd canneal_dataset
	ok "Generating the canneal synthetic netlist..."
	# FIXME: prep_canneal_dataset.sh
	popd

	pushd gabps
	ok "Converting friendster SNAP graph for GAPBS..."
	# FIXME: converter friendster.el
	popd

	popd
}

build_kernel
build_qemu
build_utils
build_benchmarks
