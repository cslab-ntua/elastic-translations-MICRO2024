#!/usr/bin/env python

import itertools
import os   
import sys  
import subprocess
import shlex    

import numpy as np  
import pandas as pd 
import seaborn as sns

import statistics   
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

from collections import Counter
from collections import OrderedDict

from ctypes import *
cycles = {}
tlbmisses = {}

pcycles = {}
ptlbmisses = {}

benchmarks = os.environ.get("BENCHMARKS", "hashjoin svm").split()
base = os.environ.get("BASE", "/root/elastic-translations-MICRO2024")

for bench in benchmarks:
    pcycles[bench] = {}
    ptlbmisses[bench] = {}
    for t in ["4KiB", "THP", "ET", "ET-offline"]:
        pcycles[bench][t] = 0
        ptlbmisses[bench][t] = 0

pdc={}
pdt={}
for bench in benchmarks:
    cycles[bench] = []
    tlbmisses[bench] = []

    #base
    path = f"{base}/results/host/eval/frag0/{bench}.4KB.base.tcmalloc-norelease.nokcompactd.1000ms/5"
    file = open(path)
    for line in file.readlines():
        if bench in ["omnetpp", "astar"]:
            if "cycles" in line and "numactl" not in line:
                cycles[bench].append(int(line.split()[0]))
            if "dtlb_walk" in line and "numactl" not in line:
                tlbmisses[bench].append(int(line.split()[0]))
        else:
            if "cycles:" in line:
                cycles[bench].append(int(line.split(":")[1]))
            if "dtlb_walk:" in line:
                tlbmisses[bench].append(int(line.split(":")[1]))
    pcycles[bench]["4KiB"] = cycles[bench][-1]
    ptlbmisses[bench]["4KiB"] = tlbmisses[bench][-1]


    #THP
    path = f"{base}/results/host/eval/frag0/{bench}.4KB.thp.tcmalloc-norelease.nokcompactd.1000ms/5"
    file = open(path)
    for line in file.readlines():
        if bench in ["omnetpp", "astar"]:
            if "cycles" in line and "numactl" not in line:
                cycles[bench].append(int(line.split()[0]))
            if "dtlb_walk" in line and "numactl" not in line:
                tlbmisses[bench].append(int(line.split()[0]))
        else:
            if "cycles:" in line:
                cycles[bench].append(int(line.split(":")[1]))
            if "dtlb_walk:" in line:
                tlbmisses[bench].append(int(line.split(":")[1]))
    pcycles[bench]["THP"] = cycles[bench][-1]
    ptlbmisses[bench]["THP"] = tlbmisses[bench][-1]


    #online
    path = f"{base}/results/host/eval/frag0/{bench}.4KB.thp.tcmalloc-norelease.etonline.nokcompactd.1000ms/5"
    file = open(path)
    for line in file.readlines():
        if bench in ["omnetpp", "astar"]:
            if "cycles" in line and "numactl" not in line:
                cycles[bench].append(int(line.split()[0]))
            if "dtlb_walk" in line and "numactl" not in line:
                tlbmisses[bench].append(int(line.split()[0]))
        else:
            if "cycles:" in line:
                cycles[bench].append(int(line.split(":")[1]))
            if "dtlb_walk:" in line:
                tlbmisses[bench].append(int(line.split(":")[1]))
    pcycles[bench]["ET"] = cycles[bench][-1]
    ptlbmisses[bench]["ET"] = tlbmisses[bench][-1]

    #offline
    path = f"{base}/results/host/eval/frag0/{bench}.4KB.thp.tcmalloc-norelease.leshy.nokcompactd.1000ms/5"
    file = open(path)
    for line in file.readlines():
        if bench in ["omnetpp", "astar"]:
            if "cycles" in line and "numactl" not in line:
                cycles[bench].append(int(line.split()[0]))
            if "dtlb_walk" in line and "numactl" not in line:
                tlbmisses[bench].append(int(line.split()[0]))
        else:
            if "cycles:" in line:
                cycles[bench].append(int(line.split(":")[1]))
            if "dtlb_walk:" in line:
                tlbmisses[bench].append(int(line.split(":")[1]))
    pcycles[bench]["ET-offline"] = cycles[bench][-1]
    ptlbmisses[bench]["ET-offline"] = tlbmisses[bench][-1]

pdc = pd.DataFrame.from_dict(pcycles).T
pdt = pd.DataFrame.from_dict(ptlbmisses).T 

pdc.index = benchmarks
pdt.index = benchmarks

pdc.to_csv("./cycles.csv")
pdt.to_csv("./tlbmisses.csv")
