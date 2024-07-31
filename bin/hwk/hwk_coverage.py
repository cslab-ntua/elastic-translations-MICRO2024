#!/usr/bin/env python3
#
# Using the sampled TLB misses, calculate the TLB miss coverage of the Hawkeye
# selected / promorted pages.
#
# ./hwk_coverage.py [benchmark] [number of pages]


import sys


def main():
    base = sys.argv[1].split('-')[0]
    lines = open(f'./traces/misses/{base}.misses').readlines()
    misses = dict()
    for line in lines:
        try:
            pmd = int(line.strip(), 16) & ~((1 << 21) - 1)
            misses.setdefault(pmd, 0)
            misses[pmd] += 1
        except:
            pass
    print('Unique 2M pages: {}'.format(len(misses)))

    lines = open('./traces/hawkeye/{}.pages'.format(sys.argv[1])).readlines()
    averted = 0
    unsampled = 0
    for line in lines[:int(sys.argv[2])]:
        pmd = int(line.strip().split('-')[0], 16)
        if pmd not in misses:
            unsampled += 1
        else:
            averted += misses[pmd]

    total = sum(misses.values())
    coverage = averted / total
    print(f'averted: {averted}, total: {total}, coverage: {coverage:.4}, unsampled: {unsampled}')


if __name__ == '__main__':
    sys.exit(main())
