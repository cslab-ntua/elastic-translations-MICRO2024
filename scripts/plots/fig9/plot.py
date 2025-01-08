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

import altair as alt
from ctypes import *

plt.style.use('ggplot')
sns.set_style("whitegrid")

def rgb2hex(c):
		#print(c[0]*255)
		return "#{:02x}{:02x}{:02x}".format(int(c[0]*255),int(c[1]*255),int(c[2]*255))

def make_rgb_transparent(rgb, bg_rgb, alpha):
        return [alpha * c1 + (1 - alpha) * c2 for (c1, c2) in zip(rgb, bg_rgb)]

def apply_hatches(ax, _len, patterns):
    for i, bar in enumerate(ax.patches):
        hatch = patterns[int(i/_len)]
        bar.set_hatch(hatch)

def apply_label(ax, labels,h):
	for rect, label in zip(ax.patches, labels):
		height = rect.get_height()
		ax.text(rect.get_x() + rect.get_width() / 2, height+h, label, ha="center", va="bottom", color="black", rotation=90, fontsize=14)

plt.rcParams["figure.figsize"] = [10, 5]
plt.rcParams['xtick.labelsize']=18
plt.rcParams['ytick.labelsize']=18
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
colors["4KiB"] = palete[1]
colors["THP"] = palete[6]
colors["HugeTLB"] = palete[2]
colors["ET-aggr"] = ours
colors["ET-heap"] = ours
colors["ET-leshy"] = ours


colors["64KiB"] = make_rgb_transparent(colors["4KiB"], (1,1,1),0.3)
colors["2MiB"] = colors["THP"]
colors["32MiB"] = make_rgb_transparent(colors["2MiB"], (1,1,1),0.3)


df1=pd.DataFrame(10*np.random.rand(4,3),index=["A","B","C","D"],columns=["I","J","K"])
df2=pd.DataFrame(10*np.random.rand(4,3),index=["A","B","C","D"],columns=["I","J","K"])
df3=pd.DataFrame(10*np.random.rand(4,3),index=["A","B","C","D"],columns=["I","J","K"])

def prep_df(df, name):
		df = df.stack().reset_index()
		df.columns = ['c1', 'c2', 'values']
		df['Size'] = name
		return df

#page breakdown
df_all={}
#for name in ["astar", "omnet", "streamcl", "canneal", "PageRank" , "xsbench", "svm", "hashjoin"]:
for name in ["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
	print(name)
	df_all[name] = {} 
	if(name=="stream"):
		df_all[name]=pd.read_csv("./streamcluster.csv", skipinitialspace=True,index_col=[0])
	elif (name=="omnet"):
		df_all[name]=pd.read_csv("./omnetpp.csv", skipinitialspace=True,index_col=[0])
	elif (name=="PageRank"):
		df_all[name]=pd.read_csv("./pagerank.csv", skipinitialspace=True,index_col=[0])
	elif (name=="xsb"):
		df_all[name]=pd.read_csv("./xsbench.csv", skipinitialspace=True,index_col=[0])
	else:
		df_all[name]=pd.read_csv("./%s.csv"%name, skipinitialspace=True,index_col=[0])
	df_all[name]=df_all[name].dropna()
	df_all[name]=df_all[name].apply(pd.to_numeric)
	footprint=df_all[name]["4KiB"]["4KiB"]*4096
	df_all[name]["4KiB"]=df_all[name]["4KiB"]*4096*100/footprint
	df_all[name]["64KiB"]=df_all[name]["64KiB"]*16*4096*100/footprint
	df_all[name]["2MiB"]=df_all[name]["2MiB"]*512*4096*100/footprint
	df_all[name]["32MiB"]=df_all[name]["32MiB"]*16*512*4096*100/footprint
	df_all[name].drop('4KiB',inplace=True)
	#df_all[name].drop('THP',inplace=True)
	#df_all[name].rename(index={'mTHP':'(m)THP'},inplace=True)
	df_all[name].rename(index={'ET-Leshy-offline':'ET-L-offline'},inplace=True)
	#df_all[name].rename(index={'ET-Leshy':'ET-Leshy'},inplace=True)
	#df_all[name].rename(index={'ET-Leshy-ab':'ET-access'},inplace=True)
	#df_all[name].rename(index={'ET-access':'Access'},inplace=True)
	#df_all[name].rename(index={'ET-Greedy':'Greedy'},inplace=True)
	#df_all[name].rename(index={'ET-Leshy':'Leshy'},inplace=True)

#4K
df4K = pd.DataFrame(index=["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"],columns=df_all["astar"].index, dtype=object)
for name in ["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
	column = df_all[name]["4KiB"].values
	for i,name2 in enumerate(df4K.columns):
		print(name,name2,i)
		df4K.loc[name,name2]=column[i]
		print(name,name2,i)

#64K
df64K = pd.DataFrame(index=["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"],columns=df_all["astar"].index, dtype=object)
for name in ["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
	column = df_all[name]["64KiB"].values
	for i,name2 in enumerate(df64K.columns):
		df64K.loc[name,name2]=column[i]

#2M
df2M = pd.DataFrame(index=["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"],columns=df_all["astar"].index, dtype=object)
for name in ["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
	column = df_all[name]["2MiB"].values
	for i,name2 in enumerate(df2M.columns):
		df2M.loc[name,name2]=column[i]

#32M
df32M = pd.DataFrame(index=["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"],columns=df_all["astar"].index, dtype=object)
for name in ["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]:
	column = df_all[name]["32MiB"].values
	for i,name2 in enumerate(df2M.columns):
		df32M.loc[name,name2]=column[i]

df1 = prep_df(df4K, '4KiB')
df2 = prep_df(df64K, '64KiB')
df3 = prep_df(df2M, '2MiB')
df4 = prep_df(df32M, '32MiB')

df = pd.concat([df1, df2, df3, df4])
df['order'] = df['Size'].replace(
    {val: i for i, val in enumerate(['4KiB', '64KiB', '2MiB', '32MiB'])}
)
alt.Chart(df).mark_bar(size=17, stroke='black', filled=True, strokeWidth=3, clip=True).encode(
    x=alt.X('c2:N', title=None, sort=["stream", "astar", "omnet", "BFS", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]),
    y=alt.Y('sum(values):Q', axis=alt.Axis(grid=True, title="Distribution of translation sizes(%)", titleFontSize=38, titleFontWeight='normal'),sort=None), column=alt.Column('c1:N', title=None, sort=["stream", "astar", "omnet", "bfs", "canneal", "xsbench", "btree", "svm", "hashjoin", "gups"]),
    color=alt.Color('Size:N', scale=alt.Scale(range=[rgb2hex(colors["32MiB"]), rgb2hex(colors["2MiB"]),rgb2hex(colors["64KiB"]),rgb2hex(colors["4KiB"])]), sort=["32MiB","2MiB","64KiB","4KiB"]),
		order='order',
).properties(width=3*45-40,height=4*80
).configure_header(
    labelFontSize=28,
    labelAngle=0,
		labelBaseline='line-top',
).configure_legend(
    labelFontSize=34,
    titleFontSize=34,
		legendX= 320,
    legendY= -115,
    direction='horizontal',
		orient='none',
		title=None
).configure_axis(
    labelFontSize=30
).configure_view(
    strokeOpacity=0    
).save("pagedistr.png", engine="vl-convert")

