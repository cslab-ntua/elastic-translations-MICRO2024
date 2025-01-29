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
from matplotlib.patches import Rectangle


from collections import Counter
from collections import OrderedDict

from ctypes import *

plt.style.use('ggplot')
sns.set_style("whitegrid")

def make_rgb_transparent(rgb, bg_rgb, alpha):
        return [alpha * c1 + (1 - alpha) * c2 for (c1, c2) in zip(rgb, bg_rgb)]

def apply_hatches(ax, _len, patterns):
	for i, bar in enumerate(ax.patches):
		if bar.get_width() > 1:
			continue
		hatch = patterns[int((i-3)/_len)]
		bar.set_hatch(hatch)

def apply_label(ax, labels,h):
	for rect, label in zip(ax.patches, labels):
		if rect.get_width()>1:
			continue
		height = rect.get_height()
		ax.text(rect.get_x() + rect.get_width() / 2, height+h, label, ha="center", va="bottom", color="black", rotation=90, fontsize=29, fontweight='semibold')

plt.rcParams["figure.figsize"] = [22, 8]
plt.rcParams['xtick.labelsize']=18
plt.rcParams['ytick.labelsize']=32
plt.rcParams['lines.linewidth']=2
plt.rcParams['legend.fontsize']=18
plt.rcParams['axes.labelsize']=20
plt.rcParams['patch.edgecolor']='black'
plt.rcParams['lines.markerfacecolor']='black'
plt.rcParams['lines.markeredgecolor']='black'
plt.rcParams['axes.linewidth'] = 2
plt.rcParams['axes.facecolor'] = "white"
plt.rcParams['axes.edgecolor'] = "black"
plt.rcParams['axes.spines.top'] = True
plt.rcParams['axes.spines.bottom'] = True
plt.rcParams['axes.spines.left'] = True
plt.rcParams['axes.spines.right'] = True  
plt.rcParams["font.family"] = "sans"
plt.rcParams["font.serif"] = ["Times New Roman"] 

colors = {}
palete = sns.color_palette("Paired")
ours = make_rgb_transparent(palete[5], (1,1,1) , 0.8)
ours2 = make_rgb_transparent(palete[5], (1,1,1) , 0.4)
colors["4KiB"] = palete[1]
colors["THP"] = palete[7]
colors["ET"] = ours
colors["ET-offline"] = ours2


cols = ["4KiB", "THP", "ET", "ET-offline"]

#cycles
df = pd.read_csv("./cycles.csv", skipinitialspace=True, index_col=[0])
df.apply(pd.to_numeric)
df["THP"] = df["4KiB"]/df["THP"]
df["ET"] = df["4KiB"]/df["ET"]
df["ET-offline"] = df["4KiB"]/df["ET-offline"]

df.rename(index={"streamcluster":"Streamcl"}, inplace=True)
df.rename(index={"omnetpp":"Omnet"}, inplace=True)

df=df[cols]
df.drop('4KiB',axis=1,inplace=True)
f, ax = plt.subplots()
ax.set_ylim([0,2.9])

df.plot.bar(color=colors, ax=ax, legend=False, width=0.89,linewidth=3)
ax.set_xticklabels(labels=df.index ,rotation=28, fontsize=38)
ax.set_ylabel("Speedup to 4KiB", fontsize=42)
patterns = ['', '//', 'x', '' ,'*']
apply_hatches(ax, len(df),patterns)

tags= ["" for x in df['THP']] + ["%.2f"%x  for x in df['ET']] + ["%.2f"%x  for x in df['ET-offline']]

apply_label(ax,tags,0.03)


handles, labels = plt.gca().get_legend_handles_labels()
order=[0,1,2]
lgd = ax.legend([handles[idx] for idx in order], [labels[idx] for idx in order], loc='upper center', bbox_to_anchor=(0.48, -0.17), ncol=5, frameon=False, fancybox=False, shadow=False, fontsize=34)
f.savefig("./speedup-nofrag.pdf", bbox_inches='tight')

#misses
df = pd.read_csv("./tlbmisses.csv", skipinitialspace=True, index_col=[0])
df.apply(pd.to_numeric)
df['THP']=(df['4KiB']-df['THP']).div(df['4KiB'], axis=0)*100
df['ET']=(df['4KiB']-df['ET']).div(df['4KiB'], axis=0)*100
df['ET-offline']=(df['4KiB']-df['ET-offline']).div(df['4KiB'], axis=0)*100

df.rename(index={"streamcluster":"Streamcl"}, inplace=True)
df.rename(index={"omnetpp":"Omnet"}, inplace=True)
df.drop('4KiB', axis=1, inplace=True)
f, ax = plt.subplots()
ax.set_ylim([0,150])

df.plot.bar(color=colors, ax=ax, legend=False, width=0.89, linewidth=3)
ax.set_xticklabels(labels=df.index ,rotation=28, fontsize=36)
ax.set_ylabel("L2 TLB miss reduction (%)", fontsize=42)
patterns = ['', '//', 'x', '' ,'*']
apply_hatches(ax, len(df),patterns)
tags= [""] + [""] + [""] + ["" for x in df['THP']] + ["%.2f"%x  for x in df['ET']] + ["%.2f"%x  for x in df['ET-offline']]
apply_label(ax,tags,1)
handles, labels = plt.gca().get_legend_handles_labels()
order=[0,1,2]
lgd = ax.legend([handles[idx] for idx in order], [labels[idx] for idx in order], loc='upper center', bbox_to_anchor=(0.48, -0.17), ncol=5, frameon=False, fancybox=False, shadow=False, fontsize=34)
f.savefig("./tlbmisses-nofrag.pdf", bbox_inches='tight')
