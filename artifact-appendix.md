-   [Artifact Appendix](#artifact-appendix)
    -   [Abstract](#abstract)
    -   [Artifact check-list
        (meta-information)](#artifact-check-list-meta-information)
    -   [Description](#description)
        -   [How to access](#how-to-access)
        -   [Hardware dependencies](#hardware-dependencies)
        -   [Software dependencies](#software-dependencies)
        -   [Data sets](#data-sets)
    -   [Installation](#installation)
    -   [Experiment workflow](#experiment-workflow)
    -   [Evaluation and expected
        results](#evaluation-and-expected-results)
    -   [Experiment customization](#experiment-customization)
    -   [Methodology](#methodology)
    -   [Troubleshooting](#troubleshooting)

# Artifact Appendix

## Abstract

The artifact comprises a [parent Git
repository](https://github.com/cslab-ntua/elastic-translations-MICRO2024),
hosted on GitHub, which includes the necessary instructions
(*README.md*), scripts (*scripts/*), binaries (*bin/, benchmarks/*),
datasets (*datasets/*) and source code (*src/*) to build, run and
evaluate *Elastic Translations*. The source code for each required
component is split into its own Git repository, which is then included
in the parent repository as a Git submodule.

ET is [implemented](https://github.com/cslab-ntua/et-linux) on top of
Linux v5.18.19. The *et-linux* repo also includes our
[Hawkeye](https://github.com/apanwariisc/HawkEye) port to Linux v7.18.19
on arm64 and the kernel configs we used to evaluate *ET* and *Hawkeye*
for both native (Ampere Altra, NVIDIA GH200) and virtualized (QEMU)
scenarios. The *Leshy* profiler along with various userspace tools and
utilities (memory fragmentation tool, ET userspace configuration
utility, accessbit sampler, etc.) are included in the
[etutils-rs](https://github.com/cslab-ntua/etutils-rs) repo. We also
provide repos for our slightly modified
[QEMU](https://github.com/cslab-ntua/et-qemu) and [gperftools
tcmalloc](https://github.com/cslab-ntua/et-gperftools). Finally, we
include a [repo](https://github.com/cslab-ntua/linux-mthp) with the
Linux kernel v6.8rc+ source we used to evaluate *mTHP* (multi-sized
THP).

We provide, in the parent repository, the [source
code](https://github.com/cslab-ntua/elastic-translations-MICRO2024/tree/et-micro-artifact/src/benchmarks)
for the *hashjoin, svm, btree, gups and bfs* benchmarks we use in the
evaluation as well as a patch (to enable profiling) for the PARSEC
benchmarks we used (*canneal and streamcluster*). The SPEC CPU
benchmarks (*astar, omnetpp*) don’t require any modifications. We also
include the scripts necessary to download and create or prepare the
input datasets of the *canneal, svm and bfs* benchmarks. To ease the
initial evaluation, we also provide pre-built images and binaries for
the kernels, userspace tools and the benchmarks as well as the prepared
datasets.

Using the scripts provided in the parent repo, one can prepare
(*scripts/prepare.sh*) the host for building, running and evaluating ET.
*scripts/build.sh* builds the *ET, Hawkeye, mTHP* kernels as well as the
userspace utilities and benchmarks. The built artifacts are installed
via *scripts/install.sh*. Finally, we provide run scripts under *scripts/run*.sh*,
which configure the host and run the user-selected benchmarks and scenarios.
We intend to also provide in the future reporting scripts to summarize and possibly plot
the results generated from the above-mentioned run scripts.

For the evaluation, an *ARMv8.2+-A* server is required. The
paper-reported results were obtained on an *Ampere Altra Mt.Jade*
2-socket server, with 80 Neoverse N1 cores and 256GiB of memory in each
socket. For both native and virtualized scenarios, we used Ubuntu Jammy
22.04. Results might vary if a server with different ARM cores is used,
especially in the case TLB size differs.

## Artifact check-list (meta-information)

-   **Data sets:**
    [KDD12](https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/binary/kdd12.xz)
    for SVM,
    [Friendster](https://snap.stanford.edu/data/com-Friendster.html)
    SNAP graph for GAPBS/BFS, synthetically generated netlist for
    Canneal

-   **Run-time environment:** Ubuntu Jammy 22.04

-   **Hardware:** ARMv8.2+-A server, preferably one with Neoverse N1
    cores (e.g. Ampere Altra)

-   **Metrics:** Cycles, L2 TLB misses, wall-clock time,
    translation-size distribution

-   **Experiments:** Native execution with and without fragmentation,
    virtualized execution without fragmentation

-   **How much disk space required (approximately)?:** 100GiB

-   **How much time is needed to prepare workflow (approximately)?:**
    ∼<!-- -->1hr

-   **How much time is needed to complete experiments
    (approximately)?:** ∼ 12hr

-   **Publicly available?:** Yes, on
    [GitHub](https://github.com/cslab-ntua/elastic-translations-MICRO2024),

-   **Code licenses (if publicly available)?:** GPLv2 (for
    newly-developed code) and other free software and open source
    licenses used by projects included in the artifact

-   **Archived (provide DOI)?:** [10.5281/zenodo.13621499](https://doi.org/10.5281/zenodo.13621499)

## Description

### How to access

The artifact is hosted on
[GitHub](https://github.com/cslab-ntua/elastic-translations-MICRO2024).
To access it clone the repository and all of its submodules:

    # git clone --recurse-submodules
        https://github.com/cslab-ntua/
            elastic-translations-MICRO2024

We also provide a script and a VM "artifact bundle" in the parent
artifact repo, to ease and speed-up the initial testing and evaluation
phase. *scripts/install_vm_bundle.sh* will download the artifact bundle
compressed tarball which includes a VM (QCOW2) image (*artifact.img*),
under *artifact_vm_bundle*, with the latest version of the artifact
already checked-out. It also includes a run script (*run-vm.sh*), which
you can use to spawn a QEMU VM. Insid the `artifact-vm-bundle` directory in the
root repo, run:

	# bash run-vm.sh

This should spawn the QEMU VM. You can then access it either via the QEMU
console, using the credentials ubuntu / ubuntu, or by SSHing to the VM:
	
	# ssh -p65433 ubuntu@localhost

using the same credentials.

The artifact bundle also includes an ED2551 SSH key pair. The public key is already installed
in the artifact bundle img (*artifact.img*) for both root and ubuntu users.

Finally, you can also use the `run-vm-noefi.sh` script, for booting pre-built VM kernels
directly from the host, without booting to GRUB.
The artifact bundle includes some precompiled VM kernels under *kernels/*.

### Hardware dependencies

ET requires a machine with ARMv8-A CPUs with support for the contig-bit
in their TLBs (cf. ARMv8-A architecture reference manual D8.6.1). Leshy
also requires support for the ARMv8.2-A Statistical Profiling Extension
(SPE) (ARMv8-A architecture reference manual A2.14). The benchmarks have
a maximum memory footprint of 122GiB. For the paper, we used a 2-socket
Ampere Altra Mt.Jade server, with 80 Neoverse N1 (ARMv8.2+-A) CPUs and
256GiB memory in each socket. We’ve also verified that ET run on NVIDIAs
Grace (ARMv9 Neoverse V2) and provide the kernel config we used to build
and boot our kernel on NVIDIA GH200.

### Software dependencies

For our evaluation, we used Ubuntu Jammy (22.04) for both native and
virtualized execution. We list and install the required packages for
building and running the artifact in *scripts/prepare.sh*.

### Data sets

-   SVM:
    [KDD12](https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/binary/kdd12.xz)

-   BFS:
    [Friendster](https://snap.stanford.edu/data/com-Friendster.html)
    SNAP graph, converted to a GAPBS-ingestible (edgelist) format

-   Canneal: synthetically generated netlist, created by the (provided)
    script *prepare_canneal_dataset.sh*

## Installation

The artifact scripts use the `$BASE` environmental variable for the base / root
artifact repo. It can be set either by directly editing the scripts or by
exporting it to the desired path, i.e.:

	# export BASE="/root/elastic-translations-MICRO24-artifact"

Then, inside the cloned parent repository run:

    # ./scripts/prepare.sh
    # VM=1 KERNEL="et.full" ./scripts/build.sh
    # VM=1 KERNEL="et.full" ./scripts/install.sh
    # reboot

After installing and booting the desired kernel, one can configure and
run *scripts/run_test.sh* to verify that everything works.

    # ./scripts/run_test.sh

Both *build.sh* and *install.sh* include knobs to configure and build
various Linux kernels and kernel configurations, controlled by the
*KERNEL* and *VM* environmental variables. One can also navigate to the
individual kernel, QEMU and benchmark source directories and manually
configure and build each component as well as generate or download the
required datasets.

## Experiment workflow

For the evaluation, one would generally:

-   configure, build and boot the required kernel (ET, Hawkeye,
    Vanilla), either via *scripts/{prepare, build}.sh* or manually,

-   use or modify any of the *run scripts (scripts/run\*.sh)* (TBA) to
    run the experiment,

-   analyze, parse and plot the results under *results/{host, vm}* and possibly plot them
    (scripts/plot\*.sh TBA).

## Evaluation and expected results

For the evaluation, the artifact includes several *run scripts*:

- *scripts/run-test.sh* is a minimal script to test that ET works. By tweaking the variables (which are read by *bin/run.sh*, *bin/run-benchmarks.sh*, *bin/prctl.sh*, *bin/frag.sh* and the env scripts under *env/*), one can do ET and non-ET runs with various configurations.

- *scripts/run-fig2-hugetlb.sh* is used to reproduce the 64KiB and 32MiB intermediage translation performance via HugeTLB (Figure 2 in the paper). The script can be tweaked to change the workloads that should be run (*BENCHMARKS*), the number of iteration for each workload (*ITER*) and the translation sizes to evaluate (*sizes*). The script will perform both native and virtualized runs, but either can be commented out / skipped, if need be.

- *scripts/run-fig15-pflat.sh* is used to reproduce the fault latency CDF of Fig. 15. This requires a pftrace-enabled kernel (CONFIG_PFTRACE). Note that for the 64KiB and 32MiB non-ET fault latencies, different kernels are required, compiled with the *CONFIG_ARM64_64K_PAGES* and *CONFIG_ARM64_16K_PAGES* options set respectively.

- *scripts/run-fig14-multi.sh* will run the three workload mixes from Fig. 14. The *RUN* env variable controls whether to do a *baseline* or an *et* run. The script can be tweaked to omit or add mixes and workloads.

- *scripts/run-fig10-virt.sh* is used to reproduce the virtualized execution results of Fig. 10.  The *RUN* env variable controls whether to do a *baseline*, an *et* or a *hwk* run. Similarly to the other scripts, the workloads (*BENCHMARKS*), iterations (*ITER*), and other options can be tweaked as needed.

- *scripts/run-eval-base.sh* is the bulkiest script, which can be used to reproduce the results from figures 8, 11, 12, and 13 of the paper. Specifically, using the *RUN* variable one can select between:
  * baseline:  THP
  * mTHP: requires 6.8/6.9-rc mTHP kernel
  * et: requires 5.18.19-et kernel
  * hawkeye: requires 5.18.19-hwk kernel
  * trident: requires 4.17.x-tr kernel

  The runs can be tweaked to generate the results for
  * Fig. 8: native, unset FRAG_TARGET
  * Fig. 11: native, FRAG_TARGET=50, FRAG_TARGET=99
  * Fig. 12: native, RUN=et, select between the various provided scenarios in the script
  * Fig. 13: native, RUN=et, ACCESSBIT=1

  Documenting and testing *scripts/run-eval-base.sh* is still a Work-in-Progress.

## Experiment customization

The artifact’s main driving scripts are *bin/run\*.sh* and
*bin/prctl.sh*. Each script can be configured via environmental
variables to e.g., run different ET or Hawkeye scenarios. *run.sh* is
the wrapper script which drives *run-benchmarks.sh*. Finally, for
Hawkeye and ET, *run-benchmarks.sh* will call *prctl.sh* for ET and
Hawkeye-specific configuration.

## Methodology

As mentioned in the paper, in order to reduce noise and variance, we use
the *userspace CPU frequency governor* provided by Linux to set the CPU
frequency to *2.7GHz* (Ampere Altra utilizes Nevorse N1 cores with a max
frequency of 3GHz, without the ability to boost past 3GHz). We also
utilize *gperftools tcmalloc* to minimize the effect of userspace
allocations on THP utilization (as is commonly done in literature). We
use *numactl* and *taskset* to pin threads to cores, both for native and
virtualized execution, in order to minimize scheduling effects and
interference. For virtualized execution, we also provide the
*scripts/vm/pincpus.py* Python script to pin vCPU QEMU threads to cores
on the host.

For the evaluation metrics, we use the architectural HW perf events
(AVMv8 PMUv3), which include *cycles, TLB misses, wall-clock time and
page faults*. ARMv8/9-A has recently added support for page walk cycles
tracing (ARMv9.1-A). We intend to extend our evaluation harness to also
support these events, which could enhancethe accuracy of the address
translation overhead measurements. With the exception of SPEC CPU
workloads (which are wrapped and run via the Linux *perf* userspace
tool), we opt to use *libperf* to enable and disable perf event tracing
for different phases of the evaluated workloads (i.e., initialization
and compute). We wrap this functionality under the *tcrperf.h* header,
which provides a simple API to toggle perf event tracing and allows us
to also collect the page table status of each workload at the end of its
execution. To that end, we also develop a [*page-collect*
tool](https://github.com/cslab-ntua/etutils-rs/blob/451a6eb7c9087c548a22debb586a15788ea4ed71/src/pagecollect.rs),
which uses the Linux procfs *pagemap* feature, to analyze the page
tables of the workloads and output the distribution of used translation
sizes (4K, ContPTE, THP, ContPMD). For virtualized execution, we also
develop a [shadow-pagetable
dump](https://github.com/cslab-ntua/et-linux/blob/47818d00eeaffc6619273e3fab7daff083dc97d8/arch/arm64/kvm/sptdump.c)
feature for the Linux kernel (*SPTE_DUMP* Kconfig option), in order to
dump the KVM SPTEs. We also communicate the page-collect output from the
VM to the host via
[VSOCK](https://github.com/cslab-ntua/etutils-rs/blob/451a6eb7c9087c548a22debb586a15788ea4ed71/src/gpasend.rs)
in order to calculate the 2D translation size coverage. For the rest of
the measured values (e.g., memory used etc.) we rely on Linux *procfs*,
which exposes system-wide and per-process metrics. Finally, for the
paper results, we ran each workload / configuration three times and
reported the arithmetic mean.

We also provide the *bin/fmfi.py* and *bin/status.sh* scripts to check
the fragmentation status (FMFI, Section VI) and the host configuration
(ET configuration, khugepaged / THP configuration, etc.). We provide the
*bin/frag.sh*, which can be configured per workload to fragment the host
(Figure 11 and 12). We develop our custom
[memfrag](https://github.com/cslab-ntua/etutils-rs/blob/451a6eb7c9087c548a22debb586a15788ea4ed71/src/memfrag.rs)
tool in Rust (etutils-rs), which allocates the entire NUMA node memory
and then frees a configurable amount of memory in fixed sized chunks
while maintaining a target NUMA node FMFI.

For fault latency profiling (Figure 13), we use specially patched and
configured kernels (+pftrace), which enable tracepoints along the fault
handling path. We then use the [*bin/pflat*
microbenchmark](https://github.com/cslab-ntua/etutils-rs/blob/451a6eb7c9087c548a22debb586a15788ea4ed71/src/pflat.rs)
to generate page faults and *bin/pflat.sh* script to enable, disable and
report the tracepoint results. For the 32MiB fault latency results, we
configure, build and boot a Linux kernel with a 16KiB base page size /
granule (*ARM64_16K_PAGES* Kconfig option), which results in [32MiB THP
faults](https://www.kernel.org/doc/html/latest/arch/arm64/hugetlbpage.html).

In order to generate the miss and access traces, we provide the
*bin/sample.sh* script (e.g., Section III.B, Figure 3 and 13). It
samples TLB misses by default, but setting the *ACCESSES* environmental
variable, it switches to page table sampling of the access bit.
*generate_hints.sh* can then be used to generate (offline) translation
size (*Leshy*) hints based on these traces. The *online Leshy*
functionality is implemented in the *bin/epochs.sh* script (which we are
in the progress of migrating to Rust and include a [WIP
version](https://github.com/cslab-ntua/etutils-rs/blob/451a6eb7c9087c548a22debb586a15788ea4ed71/src/online_leshy.rs)
in the *etutils-rs* repo).

## Troubleshooting

FIXME: describe how one could verify that the various ET components work as
intended, the ET online Leshy logs and traces, etc.
