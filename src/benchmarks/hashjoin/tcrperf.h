#ifndef _TCRPERF_H
#define _TCRPERF_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/perf_event.h>
#include <asm/unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>

#define PERF_PMU_TYPE 8

#define PERF_CPU_CYCLES 0x0011
#define PERF_INSTRUCTIONS 0x0008
#define PERF_L1DTLB 0x0025
#define PERF_L1ITLB 0x0026
#define PERF_L2DTLB_REFILL 0x002D
#define PERF_L2DTLB 0x002F
#define PERF_DTLB_WALK 0x0034
#define PERF_ITLB_WALK 0x0035

#define NR_HEADERS 3
#define NR_EVENTS 8

static const char *tcrperf_events[] = {
	"cycles",
	"instructions",
	"l1dtlb",
	"l1itlb",
//	"l2dtlb_refill",
	"l2dtlb",
	"dtlb_walk",
//	"itlb_walk",
	"faults",
	"time",
};

static int tcrperf_fd = -1;

void done(int signum) {
	return;
}

static inline int perf_event_open(struct perf_event_attr *hw_event, pid_t pid, 
		int cpu, int group_fd, unsigned long flags) {
	long ret;
	ret = syscall(__NR_perf_event_open, hw_event, pid, cpu, group_fd, flags);
	if (ret == -1) {
		fprintf(stderr, "Error opening perf event %llx\n", hw_event->config);
		exit(EXIT_FAILURE);
	}
	return (int)ret;
}

static inline void tcrperf_init(void) {
	struct perf_event_attr pe;

	if (!getenv("TCRPERF")) {
		return;
	}

	memset(&pe, 0, sizeof(pe));

	pe.type = PERF_TYPE_RAW;
	pe.size = sizeof(pe);	
	pe.config = PERF_CPU_CYCLES;
	pe.read_format = PERF_FORMAT_GROUP | PERF_FORMAT_TOTAL_TIME_ENABLED |
		PERF_FORMAT_TOTAL_TIME_RUNNING;
	pe.disabled = 1;
	pe.pinned = 1;
	pe.exclusive = 1;
	pe.inherit = 1;

	tcrperf_fd = perf_event_open(&pe, 0, -1, -1, 0);

	pe.disabled = 0;
	pe.pinned = 0;
	pe.exclusive = 0;

	pe.config = PERF_INSTRUCTIONS;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
	pe.config = PERF_L1DTLB;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
	pe.config = PERF_L1ITLB;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
	pe.config = PERF_L2DTLB;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
	pe.config = PERF_DTLB_WALK;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
//	pe.config = PERF_L2DTLB_REFILL;
//	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
//	pe.config = PERF_ITLB_WALK;
//	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);

	pe.type = PERF_TYPE_SOFTWARE;
	pe.config = PERF_COUNT_SW_PAGE_FAULTS;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);

	pe.type = PERF_TYPE_SOFTWARE;
	pe.config = PERF_COUNT_SW_TASK_CLOCK;
	perf_event_open(&pe, 0, -1, tcrperf_fd, 0);
}

static inline void tcrperf_start(void) {
	if (tcrperf_fd == -1) {
		return;
	}

	ioctl(tcrperf_fd, PERF_EVENT_IOC_RESET, 0);
	ioctl(tcrperf_fd, PERF_EVENT_IOC_ENABLE, 0);
}

static inline void tcrperf_stop(const char *msg, int pgc) {
	uint64_t res[NR_EVENTS + NR_HEADERS], i;

	if (tcrperf_fd == -1) {
		return;
	}

	ioctl(tcrperf_fd, PERF_EVENT_IOC_DISABLE, 0);

	if (read(tcrperf_fd, &res, sizeof(res)) == -1) {
		perror("read");
		exit(EXIT_FAILURE);
	}

	if (res[0] != NR_EVENTS) {
		fprintf(stderr, "nr events mismatch %ld\n", res[0]);
	}

	if (res[1] != res[2]) {
		fprintf(stderr, "multiplexing detected, enabled: %ld vs running: %ld\n",
				res[1], res[2]);
	}

	printf("%s\n", msg);
	for (i = 0; i < NR_EVENTS; i++) {
		printf("%s:%ld\n", tcrperf_events[i], res[NR_HEADERS + i]);
	}

	fflush(stdout);

	if (pgc) {
#if 0
		char *pgcvar = getenv("PGC");
		if (pgcvar) {
			system("pagecollect $(pgrep hashjoin)");
		}
#endif
		uint8_t c = 0xff;
		int fd = open("/dev/shm/hashjoin", O_WRONLY);
		if (fd < 0) {
			fprintf(stderr, "cannot open trigger\n");
		}
		if (write(fd, &c, 1) != 1) {
			fprintf(stderr, "cannot write to trigger\n");
		}
		close(fd);
		signal(SIGUSR1, done);
		pause();
	}
}
#endif /* _TCRPERF_H */
