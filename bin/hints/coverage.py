#!/usr/bin/env python3


import sys


def main():
    lines = open(sys.argv[1]).readlines()
    misses = dict()
    for line in lines:
        try:
            addr = int(line.strip(), 16) >> 12
            misses.setdefault(addr, 0)
            misses[addr] += 1
        except:
            pass

    print('Unique addresses: {}'.format(len(misses)))
    print('Misses: {}'.format(sum(misses.values())))

    hints = []
    lines = open(sys.argv[2]).readlines()
    for line in lines:
        start = int(line.strip().split('-')[0], 16)
        end = int(line.strip().split('-')[1], 16)
        hints.append(range(start, end))

    averted = 0

    for addr, sampled_misses in misses.items():
        if any((addr in hint for hint in hints)):
            averted += sampled_misses

    total = sum(misses.values())
    coverage = averted / total
    print(f'averted: {averted}, total: {total}, coverage: {coverage:.4}')


if __name__ == '__main__':
    sys.exit(main())
