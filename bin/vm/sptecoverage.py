#!/usr/bin/env python3

import sys

def align(v, a):
    return v & ~(a - 1)

def main():
    pfns = dict()
    with open(sys.argv[1]) as pfndump:
        for line in pfndump:
            pfn, level = line.split(',', 2)

            pfn = int(pfn.strip().split('=', 1)[1], 16)
            level = int(level.strip().split('=', 1)[1], 16)

            pfns[pfn] = level

    sptes = dict()
    with open(sys.argv[2]) as sptedump:
        for line in sptedump:
            gfn, pte, level = line.split(',', 2)

            pte = int(pte.strip().split('=', 1)[1], 16)
            cont = pte & (1 << 52)
            if cont == 0:
                continue

            gfn = int(gfn.strip().split('=', 1)[1], 16)
            level = int(level.strip().split('=', 1)[1])

            sptes[gfn] = level

    nocont4k = nocont2m = mismatch = 0
    pte4k = pte2m = 0
    for pfn, level in pfns.items():
        if level == 3:
            pte4k += 1
        elif level == 2:
            pte2m += 1

        if pfn not in sptes:
            pfn = align(pfn, 1 << 9);

        if pfn not in sptes:
            if level == 3:
                nocont4k += 1
            elif level == 2:
                nocont2m += 1
            continue

        if level > sptes[pfn]:
            mismatch += 1

    print("{} {}".format(100 - nocont4k / pte4k if pte4k else 0, 100 - nocont2m / pte2m if pte2m else 0))

if __name__ == "__main__":
    sys.exit(main())
