#!/usr/bin/env python3
# usage: ./pincpus.py [qmp unix domain socket] [cpu offset]

import sys, os, socket, json, subprocess, signal, time

def handler(signum, frame):
    pass

def main(qmp, cpu_offset):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

    retries = 0
    while True:
        try:
            s.connect(qmp)
            break
        except:
            pass

    s.recv(4096)

    s.sendall(b'{ "execute": "qmp_capabilities" }')
    s.recv(4096)

    s.sendall(b'{ "execute": "query-cpus-fast" }')
    data = json.loads(s.recv(1 << 15))

    signal.signal(signal.SIGUSR1, handler)
    signal.signal(signal.SIGTERM, handler)
    signal.signal(signal.SIGINT, handler)

    cmd = "cpufreq-set -g{governor} -d{min_freq} -u{max_freq} -c{cpu}"

    for vcpu in data["return"]:
        index = vcpu["cpu-index"]
        threadid = vcpu["thread-id"]
        print("Pining vcpu {} with threadid {} to pcpu {}".format(index,
            threadid, cpu_offset + index))
        os.sched_setaffinity(threadid, { cpu_offset + index })

        print("Pegging frequency to 2.7GHz for pcpu {}".format(index))
        subprocess.run(cmd.format(governor="userspace", min_freq="2.7GHz",
            max_freq="2.7GHz", cpu=cpu_offset + index).split(), check=True)

    signal.pause()

    for vcpu in data["return"]:
        index = vcpu["cpu-index"]
        threadid = vcpu["thread-id"]
        print("Resetting cpufreq governor for pcpu {}".format(index))
        subprocess.run(cmd.format(governor="performance", min_freq="1000MHz", max_freq="3.0GHz", cpu=index).split(), check=True)

if __name__ == "__main__":
    qmp = sys.argv[1] if len(sys.argv) > 1 else "./qmp.sock"
    cpu_offset = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    sys.exit(main(qmp, cpu_offset))
