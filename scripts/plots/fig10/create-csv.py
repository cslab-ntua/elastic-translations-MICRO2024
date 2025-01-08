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

for bench in ["streamcluster","astar", "omnetpp", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
    pcycles[bench] = {}
    ptlbmisses[bench] = {}
    for t in ["4KiB", "THP", "ET"]:
        pcycles[bench][t] = 0
        ptlbmisses[bench][t] = 0

pdc={}
pdt={}
for bench in ["streamcluster","astar", "omnetpp", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
    cycles[bench] = []
    tlbmisses[bench] = []

    #base
    if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.base.tcmalloc-norelease.nokcompactd.1000ms/1"%(bench)):
        file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.base.tcmalloc-norelease.nokcompactd.1000ms/1"%( bench),"r+")
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
    if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.thp.tcmalloc-norelease.nokcompactd.1000ms/1"%(bench)):
        file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.thp.tcmalloc-norelease.nokcompactd.1000ms/1"%( bench),"r+")
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
    if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.thp.tcmalloc-norelease.etonline.nokcompactd.1000ms/1"%(bench)):
        file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/vm/fig10/%s.4KB.thp.tcmalloc-norelease.etonline.nokcompactd.1000ms/1"%( bench),"r+")
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

pdc=pd.DataFrame.from_dict(pcycles).T
pdt=pd.DataFrame.from_dict(ptlbmisses).T 

pdc.index=['Streamcluster', 'Astar', 'Omnetpp', 'BFS', 'Canneal', 'XSBench', 'BTree', 'SVM' , 'Hashjoin', 'Gups']
pdt.index=['Streamcluster', 'Astar', 'Omnetpp', 'BFS', 'Canneal', 'XSBench', 'BTree', 'SVM' , 'Hashjoin', 'Gups']

pdc.to_csv('./cycles.csv')
pdt.to_csv('./tlbmisses.csv')
