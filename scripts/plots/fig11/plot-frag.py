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

plt.style.use('ggplot')
sns.set_style("whitegrid")

def make_rgb_transparent(rgb, bg_rgb, alpha):
        return [alpha * c1 + (1 - alpha) * c2 for (c1, c2) in zip(rgb, bg_rgb)]

def apply_hatches(ax, _len, patterns):
    for i, bar in enumerate(ax.patches):
        hatch = patterns[int(i/_len)]
        bar.set_hatch(hatch)

def apply_label(ax, labels,h):
	for rect, label in zip(ax.patches, labels):
		height = rect.get_height()
		ax.text(rect.get_x() + rect.get_width() / 2, height+h, label, ha="center", va="bottom", color="black", rotation=90, fontsize=25)

plt.rcParams["figure.figsize"] = [12, 5]
plt.rcParams['xtick.labelsize']=18
plt.rcParams['ytick.labelsize']=28
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
ours3 = make_rgb_transparent(palete[5], (1,1,1) , 0.2)
mthp1 = make_rgb_transparent(palete[6], (1,1,1) , 0.8)
mthp2 = make_rgb_transparent(palete[6], (1,1,1) , 0.6)
colors["4KiB"] = palete[1]
colors["4KiB-v6.8"] = make_rgb_transparent(palete[1], (1,1,1) , 0.8)
colors["THP"] = palete[6]
colors["mTHP-64KiB"] = mthp1
colors["mTHP"] = mthp1
colors["mTHP-2MiB"] = mthp2
colors["Hawkeye"] = palete[3]
colors["ET-Leshy"] = ours
colors["ET"] = ours
colors["ET-Leshy-offline"] = ours2
colors["ET-L-Off"] = ours2
colors["ET-offline"] = ours2
colors["ET-access"] = ours2
colors["ET-sample"] = ours
colors["ET-access-offline"] = ours2
colors["ET-sample-offline"] = ours

colors["64KiB"] = make_rgb_transparent(colors["4KiB"], (1,1,1),0.3)
colors["32MiB"] = colors["THP"]
colors["332MiB"] = make_rgb_transparent(colors["32MiB"], (1,1,1),0.3)
#colors["1GB"] = palete[5]

f, ax_all = plt.subplots(1, 2)

#50
df = pd.read_csv("./cycles-50.csv", skipinitialspace=True, index_col=[0])
print(df)
ax_all[0].set_ylim([0,1.8])
ax_all[0].set_xticklabels(labels=df.index ,rotation=30, fontsize=32)
ax_all[0].set_ylabel("Speedup to 4KiB", fontsize=32)
ax=ax_all[0]
ax.set_title("50% Frag", fontsize=32)
df.apply(pd.to_numeric)
df["THP"] = df["4KiB"]/df["THP"]
#df["mTHP"] = df["4KiB"]/df["mTHP"]
#df["Hawkeye"]=df["4KiB"]/df["Hawkeye"]
df["ET"] = df["4KiB"]/df["ET"]
df["ET-offline"] = df["4KiB"]/df["ET-offline"]
df["4KiB"] = df["4KiB"]/df["4KiB"]
df.drop('4KiB', axis=1, inplace=True)
df.plot.bar(color=colors, ax=ax, legend=False, width=0.8,linewidth=2)
ax.set_xticklabels(labels=df.index ,rotation=90, fontsize=28)
patterns = ['', '//', 'x', '','*']
apply_hatches(ax, len(df),patterns)


#99
df = pd.read_csv("./cycles-99.csv", skipinitialspace=True, index_col=[0])
ax=ax_all[1]
ax.set_ylim([0,1.8])
ax.set_title("99% Frag", fontsize=32)
df.apply(pd.to_numeric)
df["THP"] = df["4KiB"]/df["THP"]
#df["mTHP"] = df["4KiB"]/df["mTHP"]
#df["Hawkeye"]=df["4KiB"]/df["Hawkeye"]
df["ET"] = df["4KiB"]/df["ET"]
df["ET-offline"] = df["4KiB"]/df["ET-offline"]
df["4KiB"] = df["4KiB"]/df["4KiB"]
df["4KiB"] = df["4KiB"]/df["4KiB"]
df.drop('4KiB', axis=1, inplace=True)
print(df)
df.plot.bar(color=colors, ax=ax, legend=False, width=0.8,linewidth=2)
ax.set_xticklabels(labels=df.index ,rotation=90, fontsize=28)
patterns = ['', '//', 'x', '','*']
apply_hatches(ax, len(df),patterns)

handles, labels = plt.gca().get_legend_handles_labels()
order=[0,1,2]
lgd = ax.legend([handles[idx] for idx in order], [labels[idx] for idx in order], loc='lower center', bbox_to_anchor=(-0.2, 1.1), ncol=5, frameon=False, fancybox=False, shadow=False, fontsize=20)
f.savefig("./frag.png", bbox_inches='tight')

#plt.rcParams["figure.figsize"] = [10, 5]
#cols = ["THP", "ET-access-offline", "ET-sample-offline"]
#cycles
#df = pd.read_csv("./sample.csv", skipinitialspace=True, delimiter=";", index_col=[0])
#print(df)
#df.apply(pd.to_numeric)
#df["THP"] = df["4KiB"]/df["THP"]
#df["ET-access-offline"] = df["4KiB"]/df["ET-access-offline"]
#df["ET-sample-offline"] = df["4KiB"]/df["ET-sample-offline"]
#df=df[cols]
#f, ax = plt.subplots()
#ax.set_ylim([0,2.3])

#df.plot.bar(color=colors, ax=ax, legend=False, width=0.6,linewidth=3)
#ax.set_xticklabels(labels=df.index ,rotation=15, fontsize=28)
#ax.set_ylabel("Speedup to 4KiB", fontsize=35)
#tags= ["%.2f"%x for x in df['THP']] + ["%.2f"%x  for x in df['ET-access-offline']] + ["%.2f"%x  for x in df['ET-sample-offline']]
#apply_label(ax,tags,0.03)
#handles, labels = plt.gca().get_legend_handles_labels()
#order=[0,1,2]
#lgd = ax.legend([handles[idx] for idx in order], [labels[idx] for idx in order], loc='upper center', bbox_to_anchor=(1.35, 1), ncol=1, frameon=False, fancybox=False, shadow=False, fontsize=28)
#f.savefig("./samplevsaccess.pdf", bbox_inches='tight')
