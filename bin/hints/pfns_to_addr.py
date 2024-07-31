#!/usr/bin/env python3

import sys

def main():
    lines = open('./traces/{}/{}/{}.pfn.accessbit.hints'.format(sys.argv[1], sys.argv[2], sys.argv[3])).readlines()
    out = open('./traces/{}/{}/{}.accessbit.hints'.format(sys.argv[1], sys.argv[2], sys.argv[3]), 'w')
    for line in lines:
        start = int(line.strip().split('-')[0], 16) << 12
        end = int(line.strip().split('-')[1], 16) << 12
        out.write(f'0x{start:x}-0x{end:x}\n')

if __name__ == '__main__':
    sys.exit(main())
