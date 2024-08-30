#!/bin/bash
# 
# Build the various components needed for the ET artifact

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

install_kernel() {
	if [[ "${TYPE}" == "vm" ]]; then
		fail "Please run scripts/install.sh inside the VM or manually copy / install the VM kernel"
	fi

	if [[ "${KERNEL}" == "mthp" ]]; then
		pushd src/linux-mthp
		ok "Installing 6.8rc-mthp kernel..."
		cp configs/* .config
	elif [[ "${KERNEL}" == "trident" ]]; then
		pushd src/trident-linux

		ok "Installing 4.17-trident kernel..."
	else
		pushd src/et-linux
		ok "Installing ${KERNEL}..."
	fi

	ok "Installing kernel modules..."
	make modules_install

	ok "Configuring GRUB..."
	cat <<EOF >/etc/default/grub.d/99-artifact.cfg
GRUB_CMDLINE_LINUX="console=ttyAMA0 console=ttyS1 console=tty1 earlycon mitigations=off earlyprintk=serial no_hash_pointers ignore_loglevel"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL=console
EOF

	ok "Installing the kernel image..."
	make install

	ok "Installing perf..."
	cp tools/perf/perf "${BASE}/bin"

	popd
}

install_qemu() {
	pushd src/et-qemu
	ok "Installing Qemu..."
	cp build/qemu-system-aarch64 ${BASE}/bin/vm/
	cp build/pc-bios/efi-virtio.rom ${BASE}/bin/
	popd
}

install_utils() {
	pushd src/etutils-rs
	ok "Installing ET userspace utilities..."
	find ./target/release/ -maxdepth 1 -perm /ugo+x -type f | xargs -I '{}' cp '{}' "${BASE}/bin/"
	popd
}

install_benchmarks() {
	pushd src/benchmarks

	pushd hashjoin
	ok "Installing hashjoin..."
	cp hashjoin "${BASE}/benchmarks"
	popd

	pushd btree
	ok "Installing btree..."
	cp BTree "${BASE}/benchmarks"
	popd

	pushd gapbs
	ok "Installing bfs..."
	cp bfs converter "${BASE}/benchmarks"
	popd

	pushd svm
	ok "Installing svm..."
	cp train "${BASE}/benchmarks"
	popd

	pushd gups
	ok "Installing gups..."
	cp gups "${BASE}/benchmarks"
	popd

	popd
}

install_kernel
install_qemu
install_utils
install_benchmarks
