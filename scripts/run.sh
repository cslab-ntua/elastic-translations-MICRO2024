#/bin/bash
# 
# Run ET to reproduce the paper results

set -o pipefail -o errexit

source "$(dirname ${0})/common.sh"

# Figure 2
run_htlb() {

}

# Figure 3
run_sampling() {

}

# Figures 8, 9, 12
run_native_nofrag() {

}

# Figure 10
run_vm_nofrag() {

}

# Figure 11, 12, 13
run_native_frag() {

}

run_htlb
run_sampling
run_native_nofrag
run_vm_nofrag
run_native_frag
