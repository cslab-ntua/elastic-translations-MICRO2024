#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <sys/mman.h>

#include <string.h>
#include <numa.h>
#include <time.h>
#include <pthread.h>

#ifdef _OPENMP
#include <omp.h>
#endif


/*
 * ============================================================================
 * HPCC RandomAccess
 * ============================================================================
 */


///< The number of updates to the table
//#define NUPDATE (1 * TableSize)
//#define NUPDATE (1UL << 28)

#ifdef _OPENMP
//#define NUPDATE (1UL << 36)
//#define NUPDATE (1UL << 36)
#define NUPDATE (1UL << 34)
#else
//#define NUPDATE (1UL << 32)
#define NUPDATE (1UL << 28)
#endif


///< parameters for ther andom table
#define POLY 0x0000000000000007UL
#define PERIOD 1317624576693539401L


static uint64_t
HPCC_starts(int64_t n)
{
    int i, j;
    uint64_t m2[64];
    uint64_t temp, ran;

    while (n < 0) n += PERIOD;
    while (n > PERIOD) n -= PERIOD;
    if (n == 0) return 0x1;

    temp = 0x1;
    for (i=0; i<64; i++) {
        m2[i] = temp;
        temp = (temp << 1) ^ ((int64_t) temp < 0 ? POLY : 0);
        temp = (temp << 1) ^ ((int64_t) temp < 0 ? POLY : 0);
    }

    for (i=62; i>=0; i--)
        if ((n >> i) & 1)
            break;

    ran = 0x2;
    while (i > 0) {
    temp = 0;
    for (j=0; j<64; j++)
        if ((ran >> j) & 1)
            temp ^= m2[j];
        ran = temp;
        i -= 1;
        if ((n >> i) & 1)
            ran = (ran << 1) ^ ((int64_t) ran < 0 ? POLY : 0);
    }

    return ran;
}

///< the name of the shared memory file created
#define CONFIG_SHM_FILE_NAME "/tmp/alloctest-bench"

#include "tcrperf.h"

int main(int argc, char *argv[])
{
    size_t mem = ((size_t)64UL << 30);
	size_t nupdate;
    if (argc == 2) {
        mem = strtoull(argv[1], NULL, 10) << 30;    
    }

	tcrperf_init();
	tcrperf_start();

    
    for (int i = 0; i < 64; i++) {
        if (1ULL << i > mem) {
            mem = 1ULL << (i - 1);
            break;
        }
    }

    
    struct timespec time1, time2;


#if 0
	void *padding = malloc(mem >> 1);
	if (!padding) {
		fprintf(stderr, "ENOMEM\n");
		return -1;
	}
	memset(padding, 0xff, mem >> 1);
#endif

    //uint64_t *Table = malloc(mem + 16);
    uint64_t *Table;
	if (getenv("hpud")) {
		Table = mmap(NULL, mem + 16, PROT_READ | PROT_WRITE, MAP_HUGETLB | (30 << MAP_HUGE_SHIFT) | MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
	} else {
		Table = mmap(NULL, mem + 16, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
	}
    if (!Table || Table == MAP_FAILED) {
        return -1;
    }

    size_t TableSize = mem / sizeof(uint64_t);
	nupdate = NUPDATE < TableSize ? TableSize : NUPDATE;
	fprintf(stdout, "Doing %lu updates\n", nupdate);

    /* Initialize main table */
    for (size_t i=0; i<TableSize; i++) {
        Table[i] = i;
    }

    FILE *fd2 = fopen(CONFIG_SHM_FILE_NAME ".ready", "w");

    if (fd2 == NULL) {
        fprintf (stderr, "ERROR: could not create the shared memory file descriptor\n");
        exit(-1);
    }

	tcrperf_stop("gups-init", 0);

    usleep(250);

	tcrperf_start();

    /* Current random numbers */
    uint64_t *ran = calloc(128, sizeof(uint64_t));
    for (size_t j=0; j<128; j++) {
        ran[j] = HPCC_starts ((nupdate/128) * j);
    }
    volatile uint64_t *res = calloc(128, sizeof(uint64_t));

    for (size_t i=0; i<nupdate/128; i++) {
        /* #pragma ivdep */
        for (size_t j=0; j<128; j++) {
            ran[j] = (ran[j] << 1) ^ ((int64_t) ran[j] < 0 ? POLY : 0);
            size_t elm = ran[j] % TableSize;
            res[j] = (Table[elm] ^ ran[j]) + (Table[TableSize - elm] ^ ran[j]);
        }
    }

	tcrperf_stop("gups-compute", 1);

//  Don't free the table in the end, so we can check the page table
//    free(Table);

    return 0;
}
