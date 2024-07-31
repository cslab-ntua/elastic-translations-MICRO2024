#!/usr/bin/env python3

import sys
import re
import numpy as np
import matplotlib.pyplot as plt
from glob import glob

CLKFRQ = 25000000
NSECS = 1000000000
RESOLUTION = NSECS // CLKFRQ

def main():
    regexp = re.compile(r'{ cycles: ~ (?P<min>\d+)-(?P<max>\d+) } hitcount:\s+(?P<count>\d+)$')
    prefix='/sys/kernel/debug/tracing/events/'
    
    latencies = dict()
    data = []

    for file in glob(f'{sys.argv[1]}'):
        event = None
        for line in open(file).readlines():
            stripped = line.removeprefix(prefix)
            if line != stripped:
                if event is not None:
                    latencies.setdefault(event, dict())
                    latencies[event][file] = data[:]
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
            latencies.setdefault(event, dict())
            latencies[event][file] = data[:]
            data.clear()

    plt.rcParams["figure.figsize"] = (8, 6)
    plt.xscale("log")
    plt.xlabel('usecs')
    plt.ylabel('CDF')
    plt.grid()

    for (event, files) in latencies.items():
        event = event.strip().split('/')[1]

        empty = True
        for (file, data) in files.items():
            if not data or len(data) < 1000:
                continue
            empty = False
            file = file.strip().split('/')[2]
            cdf = np.linspace(0, 1, len(data), endpoint=False)
            plt.plot(data, cdf, label = f'{event}')
            #plt.plot(np.quantile(data, [0.5, 0.9, 0.95, 0.99]), [0.5, 0.9, 0.95, 0.99], 'rx', markersize=10)
            print('{} {} {}'.format(event, file, np.quantile(data, [0.5, 0.9, 0.95, 0.99])))


        if empty:
            continue

    plt.legend()
    plt.savefig(f'{sys.argv[1]}.png')

if __name__ == '__main__':
    sys.exit(main())
