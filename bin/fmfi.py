#!/usr/bin/env python3
# Compute FMFI (free memory fragmentation index)

import sys
import os.path

def main():
    for line in open("/proc/buddyinfo"):
        node, rest = line.split(',', 1)
        print(node)
        node = node.split()[1].strip()

        rest = rest.strip().split()

        free_order_pages = [int(pages) << order for order, pages in enumerate(rest[2:])]
        total_free = sum(free_order_pages)

        for order in range(0, len(free_order_pages)):
            fmfi = (total_free - sum(free_order_pages[order:])) / total_free
            print("\tOrder {:2} FMFI: {:.2f}%".format(order, fmfi * 100))


if __name__ == "__main__":
    sys.exit(main())
