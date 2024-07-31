#!/usr/bin/env python3
# Generate a (Leshy-hint-like) list of the 2M address ranges selected by
# Hawkeye.
# ./parse_hwk_trace.py [benchmark]


import re
import sys


# The raw trace is in the form of "addr@0x[addr] bin: [bin]"
RE = r'addr@0x(.+).*bin: (\d+)'


def main():
    regexp = re.compile(RE)
    lines = open('./traces/hawkeye/{}.raw'.format(sys.argv[1])).readlines()

    trace = dict()
    for line in lines:
        m = regexp.match(line.strip())
        addr = int(m.groups()[0].strip(), 16)
        prio = int(m.groups()[1].strip())
        trace[addr] = prio
        
    
    for addr in trace.keys():
        end = addr + (1 << 21)
        print(f'0x{addr:x}-0x{end:x}')


if __name__ == '__main__':
    sys.exit(main())
