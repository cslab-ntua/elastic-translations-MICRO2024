#include <iostream>
#include <fstream>
#include <iomanip>
#include <map>
#include <string>
#include <cstdint>

unsigned int PROMOTION_CACHE_SIZE = 128, FACTOR = 30;
unsigned long ACCESS_INTERVAL = 100000, total_num_accesses = 0, curr_num_accesses = 0, num_2mb_ptw = 0;
double ALPHA = 1.9;

#include "huge_page_reuse.h"
#include "hawkeye.h"

int main(int argc, char *argv[])
{
	bool pcc = argc == 1;
	uint64_t addr;
	std::ifstream trace("trace.txt");

	if (pcc) {
    	promotion_cache_init();
	}

	while (trace >> hex >> addr) {
		pcc ? pcc_track_access((uint64_t) addr) :
			hawkeye_track_access((uint64_t) addr);
	}

	summarize_reuse();

    return 0;
}
