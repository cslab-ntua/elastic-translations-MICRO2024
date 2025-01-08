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

for bench in ["bfs", "canneal", "xsbench", "btree", "svm", "hashjoin"]:
    pcycles[bench] = {}
    ptlbmisses[bench] = {}
    for t in ["4KiB", "THP", "ET", "ET-offline"]:
        pcycles[bench][t] = 0
        ptlbmisses[bench][t] = 0

pdc={}
pdt={}
for frag in [50, 99]:
    for bench in ["bfs", "canneal", "xsbench", "btree", "svm", "hashjoin"]:
        cycles[bench] = []
        tlbmisses[bench] = []

        #base
        if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.base.tcmalloc-norelease.nokcompactd.1000ms.prev/1"%(frag,bench)):
            file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.base.tcmalloc-norelease.nokcompactd.1000ms.prev/1"%(frag, bench),"r+")
            for line in file.readlines():
                if "cycles:" in line:
                    cycles[bench].append(int(line.split(":")[1]))
                if "dtlb_walk:" in line:
                    tlbmisses[bench].append(int(line.split(":")[1]))
            pcycles[bench]["4KiB"] = cycles[bench][-1]
            ptlbmisses[bench]["4KiB"] = tlbmisses[bench][-1]
    

        #THP
        if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.nokcompactd.1000ms/1"%(frag,bench)):
            file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.nokcompactd.1000ms/1"%(frag, bench),"r+")
            for line in file.readlines():
                if "cycles:" in line:
                    cycles[bench].append(int(line.split(":")[1]))
                if "dtlb_walk:" in line:
                    tlbmisses[bench].append(int(line.split(":")[1]))
            pcycles[bench]["THP"] = cycles[bench][-1]
            ptlbmisses[bench]["THP"] = tlbmisses[bench][-1]
    
        #online
        if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.etonline.nokcompactd.1000ms/1"%(frag,bench)):
            file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.etonline.nokcompactd.1000ms/1"%(frag, bench),"r+")
            for line in file.readlines():
                if "cycles:" in line:
                    cycles[bench].append(int(line.split(":")[1]))
                if "dtlb_walk:" in line:
                    tlbmisses[bench].append(int(line.split(":")[1]))
            pcycles[bench]["ET"] = cycles[bench][-1]
            ptlbmisses[bench]["ET"] = tlbmisses[bench][-1]

        #offline
        if os.path.exists("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.leshy.nokcompactd.1000ms/1"%(frag,bench)):
            file = open("/mnt/nvme0n1p2/home/micro24ae/elastic-translations-MICRO2024/results/host/eval/frag%d/%s.4KB.thp.tcmalloc-norelease.leshy.nokcompactd.1000ms/1"%(frag, bench),"r+")
            for line in file.readlines():
                if "cycles:" in line:
                    cycles[bench].append(int(line.split(":")[1]))
                if "dtlb_walk:" in line:
                    tlbmisses[bench].append(int(line.split(":")[1]))
            pcycles[bench]["ET-offline"] = cycles[bench][-1]
            ptlbmisses[bench]["ET-offline"] = tlbmisses[bench][-1]

    pdc[frag]=pd.DataFrame.from_dict(pcycles).T
    pdt[frag]=pd.DataFrame.from_dict(ptlbmisses).T 

    pdc[frag].index=['BFS', 'Canneal', 'XSBench', 'BTree', 'SVM' , 'Hashjoin']
    pdt[frag].index=['BFS', 'Canneal', 'XSBench', 'BTree', 'SVM' , 'Hashjoin']
    
    pdc[frag].to_csv('./cycles-%d.csv'%frag)
    pdt[frag].to_csv('./tlbmisses-%d.csv'%frag)
