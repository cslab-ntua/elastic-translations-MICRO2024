#!/usr/bin/env python3

import sys
import re

regexp=re.compile(r'(.*)hints for (.*), target (\d+), slack (\d+):')
start = True
out={}
benchmark = ''
mode = ''
target= 0
slack = 0

for line in open("hints.parsed").readlines():
    if start:
        m = regexp.match(line.strip())
        if m is None:
            print("malformed input!")
            sys.exit(1)

        start = False
        benchmark = m.group(2)
        mode = 'access' if m.group(1) else 'miss'
        target= int(m.group(3))
        slack = int(m.group(4))

        out.setdefault(benchmark, {})
        out[benchmark].setdefault(target, {})
        out[benchmark][target].setdefault(slack, {})
        out[benchmark][target][slack].setdefault(mode, {})
    else:
        l = line.split() 
        if len(l) == 2:
            n = int(l[0])
            s = int(l[1])

            out[benchmark][target][slack][mode][s] = n
        else:
            start = True

for k, v in out.items():
    print(k)
    for kk, vv in v.items():
        for kkk, vvv in vv.items():
            for kkkk, vvvv in vvv.items():
                print("{}\t{}\t{}\t{}".format(vvvv.get(4096, 0), vvvv.get(65536, 0),
                        vvvv.get(2097152, 0), vvvv.get(33554432, 0)))
