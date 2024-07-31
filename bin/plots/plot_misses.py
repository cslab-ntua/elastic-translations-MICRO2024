#!/usr/bin/env python3

import sys
import numpy as np
import matplotlib.pyplot as plt

def main():
    misses = dict()
    for line in open(sys.argv[1]):
        if 'XLAT' in line:
            continue

        try:
            addr = int(line.strip(), 16)
        except:
            continue
        if addr >= 0xffff000000000000:
            continue

        addr >>= 21
        misses.setdefault(addr, 0)
        misses[addr] += 1

    fig = plt.figure(figsize = (8, 6))
 
    axs = fig.subplots(2)

    _misses = misses
    first = min(_misses.keys())
    last = max(_misses.keys())
    misses = {k: v for k, v in sorted(_misses.items(), key=lambda x: x[0]) if v > 10 and k < (first + last) / 2}
    first = min(misses.keys())
    last = max(misses.keys())

    print(f'0x{first:x}, 0x{last:x}')

    values = list()
    edges = list()

    prev = first - 1
    for k, v in misses.items():
        if prev != k - 1:
            values.append(0)
            edges.append(prev)

        values.append(v)
        edges.append(k)
        prev = k

    edges.append(last + 1)

    axs[0].stairs(values, edges=edges)
    axs[0].xaxis.set_major_formatter(lambda x, _: '0x{:x}'.format(int(x * 2) >> 10))
    axs[0].tick_params(axis='x', labelrotation=45)

    first = min(_misses.keys())
    last = max(_misses.keys())
    misses = {k: v for k, v in sorted(_misses.items(), key=lambda x: x[0]) if v > 10 and k >= (first + last) / 2}
    first = min(misses.keys())
    last = max(misses.keys())

    print(f'0x{first:x}, 0x{last:x}')

    values = list()
    edges = list()

    prev = first - 1
    for k, v in misses.items():
        if prev != k - 1:
            values.append(0)
            edges.append(prev)

        values.append(v)
        edges.append(k)
        prev = k

    edges.append(last + 1)

    axs[1].stairs(values, edges=edges)
    axs[1].xaxis.set_major_formatter(lambda x, _: '0x{:x}'.format(int(x * 2) >> 10))
    axs[1].tick_params(axis='x', labelrotation=45)

    fig.subplots_adjust(hspace=1.0)
    fig.tight_layout()
    fig.savefig('misses.pdf')


if __name__ == '__main__':
    sys.exit(main())
