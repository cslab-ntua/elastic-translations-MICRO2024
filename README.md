Elastic Translations MICRO'24 Artifact
======================================

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.13621499.svg)](https://doi.org/10.5281/zenodo.13621499)

This repository contains scripts and other supplementary material for the artifact evaluation of the paper 
**Elastic Translations: Fast virtual memory with multiple translation sizes** (DOI link TBD).

ET extend Linux to optimally and transparently take advantage of ARMv8-A's OS-assisted TLB coalesecing. ET transparently supports 64KiB and 32MiB translations, both at fault time and via asynchronous *khugepaged* migrations. The *Leshy* userspace profiler, based on ARMv8-A's Statistical Profiling Extension (SPE), samples the TLB misses of applications, either at runtime or offline, and provides translation size guidance to the kernel. We plan to add RISC-V Svnapot support to ET in the future.

Authors
-------
 
 * Stratos Psomadakis (National Technical University of Athens)
 * Chloe Alverti (University of Illinois at Urbana-Champaign)
 * Vasileios Karakostas (University of Athens)
 * Christos Katsakioris (National Technical University of Athens)
 * Dimitrios Siakavaras (National Technical University of Athens)
 * Konstantinos Nikas (National Technical University of Athens)
 * Georgios Goumas (National Technical University of Athens)
 * Nectarios Koziris (National Technical University of Athens)

Paper Citation
--------------
TBD

Directory Structure
-------------------

 * `bin/` Scripts and binaries required to run the experiments
 * `benchmarks/` Benchmark binaries and datasets
 * `env/` Bash scripts to configure the environment for the experiments
 * `hints/` Precomputed Leshy hints for the benchmarks, for both TLB miss sampling and accessbit sampling traces
 * `lib/` Libraries needed to run the experiments (gperftools tcmalloc, mpich)
 * `scripts/` Artifact bash scripts to prepare the host and build, install and run the artifact, summarize and plot the results
 * `src/` Source code for the ET kernel, the ET userspace tools and utilities and the benchmarks.

Hardware Dependencies
---------------------
ET requires a machine with ARMv8-A CPUs with support for the contig-bit in 
their TLBs (cf.  ARMv8-A architecture reference manual D8.6.1). Leshy also
requires support for the ARMv8.2-A Statistical Profiline Extension (SPE)
(ARMv8-A architecture reference manual A2.14).

The benchmarks have a maximum memory footprint of 122GiB. 

For the paper, we used a 2-socket Ampere Altra Mt.Jade server, 
with 80 Neoverse N1 (ARMv8.2+-A) CPUs and 256GiB memory in each socket.

We've also verified that ET run on NVIDIAs Grace (ARMv9 Neoverse V2).

Software Dependencies
---------------------
For our evaluation, we used Ubuntu Jammy (22.04) for both native and
virtualized execution. We list and install the required packages for building
and running the artifact in `scripts/prepare.sh`.

For more information see the [artifact appendix](artifact-appendix.md).
