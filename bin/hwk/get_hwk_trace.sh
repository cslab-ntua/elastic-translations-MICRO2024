#!/bin/bash
#
# Filter hawkeye logs by mm

journalctl -kb0 --grep "mm@${1}" | awk -F ',' '{print $2 " " $3}'
