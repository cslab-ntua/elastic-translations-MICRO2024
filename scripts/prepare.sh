#/bin/bash
# 
# Setup the environment for the ET artifact

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

install_packages() {
	export DEBIAN_FRONTEND=noninteractive
	ok "Installing pacakges..."
	apt -y update
	apt -y full-upgrade --assume-yes
	apt -y install --assume-yes build-essential bison flex screen tmux \
		ripgrep libncurses-dev libssl-dev libelf-dev libunwind-dev strace \
		ltrace inotify-tools numactl git vim libnuma-dev libzstd-dev ninja-build \
		libaio-dev pkg-config libglib2.0-dev libpixman-1-dev libattr1-dev \
	       	cpufrequtils libcap-ng-dev
	apt -y purge flash-kernel
	apt -y autoremove
	apt -y autoclean
}

install_rust() {
	if [ ! -d "./bin/rust-1.80.0-aarch64-unknown-linux-gnu" ]; then
		ok "Downloading Rust..."
		${WGET} https://static.rust-lang.org/dist/rust-1.80.0-aarch64-unknown-linux-gnu.tar.xz | tar -C "./bin" --xz -xf -
		./bin/rust-1.80.0-aarch64-unknown-linux-gnu/install.sh
	fi
}

prepare_files() {
	export DATASETS="canneal.inp kdd12 fr.el"
	export FILE_HOST="83.212.99.29"

	if [ ! -d "./lib/mpi" ]; then
		ok "Downloading MPICH libraries..."
		${WGET} "${FILE_HOST}/lmpi.tzst" | tar -C "./lib" --zstd -xf -
	fi

	if [ ! -d "./traces" ]; then
		ok "Downloading traces..."
		${WGET} "${FILE_HOST}/traces.tzst" | tar --zstd -xf -
	fi

	for ds in ${DATASETS}; do
		if [ ! -f "./benchmarks/${ds}" ]; then
			ok "Downloading ${ds}..."
			${WGET} "${FILE_HOST}/${ds}.zst" | numactl -N0 -m0 zstd -T$(nproc) -d - -o "./benchmarks/${ds}"
		fi
	done
}

install_packages
prepare_files
install_rust
