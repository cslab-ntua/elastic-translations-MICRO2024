#!/bin/bash

set -e

mm=$(journalctl -rkb0 --grep 'mm@' | head -n1 | cut -f 2 -d '@' | cut -f 1 -d ',' | uniq)
echo "Getting HawkEye promotion trace for mm ${mm}..."
get_hwk_trace.sh "${mm}" > "traces/hawkeye/${1}.raw"
parse_hwk_trace.py "${1}" > "traces/hawkeye/${1}.pages"
