#!/usr/bin/env python3

import os
import sys
import re
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as tick
from glob import glob

CLKFRQ = 25000000
NSECS = 1000000000
RESOLUTION = NSECS // CLKFRQ

def parse_traces():
    regexp = re.compile(r'{ cycles: ~ (?P<min>\d+)-(?P<max>\d+) } hitcount:\s+(?P<count>\d+)$')
    prefix='/sys/kernel/debug/tracing/events/'
    
    latencies = dict()
    data = []

    for file in glob(f'{sys.argv[1]}'):
        if os.path.isdir(file):
            continue

        if file not in latencies:
            latencies[file] = dict()

        event = None
        for line in open(file).readlines():
            stripped = line.removeprefix(prefix)
            if line != stripped:
                if event is not None:
                    event = event.strip().split('/')[1]
                    latencies[file][event] = data[:]
                    data.clear()

                event = stripped
                continue

            m = regexp.match(line.strip())
            if not m:
                continue

            lower = int(m['min']) * RESOLUTION;
            upper = int(m['max']) * RESOLUTION;

            data.extend([(upper + lower) // 2 / 1000.0] * int(m['count']))

        if event is not None:
            event = event.strip().split('/')[1]
            latencies[file][event] = data[:]
            data.clear()

    return latencies

def aggregate(latencies):
    x = {'base': [], 'thp': []}
    y = {'base': dict(), 'thp': dict()}

    for (file, events) in latencies.items():
        file = file.strip().split('/')[1]

        size = 'base'
        if 'thp' in file:
            size = 'thp'

        x[size].append(file)

        for (event, data) in events.items():
            y[size].setdefault(event, [])
            if len(data):
                avg = sum(data) / len(data)
                y[size][event].append(avg)
                #print('{}-{} {:.2} {:.2} {:.2}'.format(file, event, avg, np.percentile(data, 50), np.percentile(data, 99)))
                if event == 'fault':
                    print('{}-{} {:.2} {:.2} {:.2}'.format(file, event, avg, np.percentile(data, 50), np.percentile(data, 99)))
                    event = 'rest'
                    y[size].setdefault(event, [])
                    y[size][event].append(avg)
            else:
                y[size][event].append(0)

    return x, y

def breakdown(y, upper=False):
    for (i, val) in enumerate(y['rest']):
        y['rest'][i] = val - y['allocpages'][i] - y['setpte'][i]

    if upper:
        return

    for (i, val) in enumerate(y['allocpages']):
        if y['allocpages_capaging'][i] != 0:
            y['allocpages'][i] = val - y['allocpages_capaging'][i]
        else:
            y['allocpages'][i] = val - y['rmqueue'][i]

    for (i, val) in enumerate(y['allocpages_capaging']):
        if val != 0:
            y['allocpages_capaging'][i] = val - y['rmqueue'][i] - y['rmqueue_capaging'][i]

    for (i, val) in enumerate(y['rmqueue_capaging']):
        y['rmqueue_capaging'][i] = val - y['ptescan'][i] - y['pmdscan'][i]

    for (i, val) in enumerate(y['setpte']):
        y['setpte'][i] = val - y['etset'][i]

def main():
    latencies = parse_traces()

    x, y = aggregate(latencies)
    xx, yy = aggregate(latencies)

    breakdown(yy['base'], True)
    breakdown(yy['thp'], True)

    breakdown(y['base'])
    breakdown(y['thp'])

    evts = ['rest', 'allocpages', 'allocpages_capaging', 'rmqueue', 'rmqueue_capaging', 'ptescan', 'pmdscan', 'setpte', 'etset', 'etflush']
    colors = {
            'rest': 'gray',
            'allocpages': 'red',
            'allocpages_capaging': 'red',
            'rmqueue': 'green',
            'rmqueue_capaging': 'green',
            'ptescan': 'olive',
            'pmdscan': 'olive',
            'setpte': 'cyan',
            'etset': 'cyan',
            'etflush': 'yellow',
        }
    hatches = {
            'rest': '/',
            'allocpages': '/',
            'allocpages_capaging': 'xx',
            'rmqueue': '/',
            'rmqueue_capaging': 'xx',
            'ptescan': 'xx',
            'pmdscan': 'xx',
            'setpte': '/',
            'etset': 'xx',
            'etflush': 'xx',
        }
    bottom = [[[0] * len(x['base']), [0] * len(x['thp'])], [[0] * len(x['base']), [0] * len(x['thp'])]]

    fig, axs  = plt.subplots(2, 2, figsize=(8, 12))

    for evt in evts:
        if evt in ['rest', 'allocpages', 'setpte']:
            axs[0][0].bar(xx['base'], yy['base'][evt], width=0.5, label=evt, hatch=hatches[evt], bottom=bottom[0][0], color=colors[evt])
            bottom[0][0] = [n + yy['base'][evt][j] for j, n in enumerate(bottom[0][0])]

        if sum(y['base'][evt]) and evt != 'rest':
                axs[1][0].bar(x['base'], y['base'][evt], width=0.5, label=evt, hatch=hatches[evt], bottom=bottom[1][0], color=colors[evt])
                bottom[1][0] = [n + y['base'][evt][j] for j, n in enumerate(bottom[1][0])]

        if evt in ['rest', 'allocpages', 'setpte']:
            axs[0][1].bar(xx['thp'], yy['thp'][evt], width=0.5, label=evt, hatch=hatches[evt], bottom=bottom[0][1], color=colors[evt])
            bottom[0][1] = [n + yy['thp'][evt][j] for j, n in enumerate(bottom[0][1])]

        if sum(y['thp'][evt]) and evt != 'rest':
                axs[1][1].bar(x['thp'], y['thp'][evt], width=0.5, label=evt, hatch=hatches[evt], bottom=bottom[1][1], color=colors[evt])
                bottom[1][1] = [n + y['thp'][evt][j] for j, n in enumerate(bottom[1][1])]

    axs[0][0].yaxis.set_minor_locator(tick.AutoMinorLocator())
    axs[1][0].yaxis.set_minor_locator(tick.AutoMinorLocator())

    axs[0][0].tick_params(axis='y', which='minor', bottom=False)
    axs[1][0].tick_params(axis='y', which='minor', bottom=False)

    axs[0][0].set_ylim(top=max(y['base']['fault']) * 1.1)

    axs[0][0].set_ylabel('usecs')
    axs[1][0].set_ylabel('usecs')

    axs[0][0].set_title('4K fault latency')
    axs[1][0].set_title('4K alloc latency')

    axs[0][1].yaxis.set_minor_locator(tick.AutoMinorLocator())
    axs[1][1].yaxis.set_minor_locator(tick.AutoMinorLocator())

    axs[0][1].tick_params(axis='y', which='minor', bottom=False)
    axs[1][1].tick_params(axis='y', which='minor', bottom=False)

    axs[0][1].set_ylim(top=max(y['thp']['fault']) * 1.1)

    axs[0][1].set_ylabel('usecs')
    axs[1][1].set_ylabel('usecs')

    axs[0][1].set_title('THP fault latency')
    axs[1][1].set_title('THP alloc latency')

    h, l= axs[0][1].get_legend_handles_labels()
    hh, ll = axs[1][1].get_legend_handles_labels()

    lgd = fig.legend([h[0], ] + hh, [l[0], ] + ll, ncols=3, loc="lower center",
            bbox_to_anchor=(0.5, -0.01))

    fig.suptitle('Fault latency breakdown')
    fig.savefig(f'{sys.argv[2]}.png', bbox_extra_artists=(lgd,), bbox_inches='tight')

if __name__ == '__main__':
    sys.exit(main())
