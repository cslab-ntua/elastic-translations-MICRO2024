#!/bin/bash

export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
source "${BASE}/env/base.env"
pushd "${BASE}"

export KHUGE=1
export KHUGE_SLEEP=1000
export KHUGE_HWK=1
export NOKCOMPACTD=1

unset FRAG_TARGET
export MODE="etheap"
export BENCHMARKS="hashjoin"
export RESULTS="report/frag${FRAG_TARGET:-0}"

PGSZ=thp run.sh
