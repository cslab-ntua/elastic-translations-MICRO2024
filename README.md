Elastic Translations MICRO'24 Artifact
======================================

This repository contains scripts and other supplementary material for the artifact evaluation of the paper 
**Elastic Translations: Fast virtual memory with multiple translation sizes** (link TBD)

The README mostly mirrors the information provided in the artifact appendix
included in the paper (PDF link TBD).

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

Directory Structure
-------------------

 * `bin/` Scripts and binaries required to run the experiments
 * `benchmarks/` Benchmark binaries and datasets
 * `env/` Bash scripts to configure the environment for the experiments
 * `hints/` Precomputed Leshy hints for the benchmarks, for both TLB miss sampling and accessbit sampling traces
 * `lib/` Libraries needed to run the experiments (gperftools tcmalloc, mpich)
 * `scripts/` Artifact bash scripts to prepare the host and build, install and run the artifact
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

Installation
------------
TBD

Configuration
-------------
TBD

Running the Experiments
-----------------------
TBD

Paper Citation
--------------
TBD
