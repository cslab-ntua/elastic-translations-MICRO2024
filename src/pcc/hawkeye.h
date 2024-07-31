#include <bitset>
#include <unordered_map>

#define ACC_COV_VAL 1
#define NUM_BUCKETS 10
#define BUCKET_SIZE 50
#define NUM_BASE_PAGES 512
#define MAX_NUM_PROMOTIONS 8

bool tracking = true;
unordered_map<uint64_t, bitset<NUM_BASE_PAGES>> coverage;
unordered_map<uint64_t, double> ema;
vector<uint64_t> buckets[NUM_BUCKETS];
unordered_map<uint64_t, unsigned short> hawkeye_promotions;

void clear_coverage() {
  uint64_t base;
  for (auto it : coverage) {
    base = it.first;
    coverage[base].reset();
  }
}

void change_bucket(uint64_t base, int old_bucket, int new_bucket) {
  if (new_bucket < 0) {
    cout << "NEW BUCKET < 0!" << endl;
    new_bucket = 0;
  }
  if (new_bucket > NUM_BUCKETS-1) new_bucket = NUM_BUCKETS-1;

  for (unsigned long i = 0; i < buckets[old_bucket].size(); i++) {
    if (buckets[old_bucket][i] == base) {
      buckets[old_bucket].erase(buckets[old_bucket].begin() + i);
      break;
    }
  }
  buckets[new_bucket].push_back(base);
}

void summarize() {
  uint64_t base, acc_cov;
  int old_bucket, new_bucket, bucket_idx, num_promotions;
  unsigned long idx;
  double acc_ema;
  bool repeat_promotion;

  cout << "\n" << dec << total_num_accesses << hex << ": Memory Regions:" << endl;
  for (auto it : coverage) {
    base = it.first;
    acc_cov = (it.second).count();

    if (ema.find(base) != ema.end()) acc_ema = ALPHA*ema[base] + (1-ALPHA)*acc_cov;
    else acc_ema = acc_cov;

    old_bucket = (int) (ema[base]/BUCKET_SIZE);
    ema[base] = acc_ema;
    new_bucket = (int) (ema[base]/BUCKET_SIZE);

    change_bucket(base, old_bucket, new_bucket);

    //cout << "\tbase = " << hex << base << ", " << acc_ema << dec << ", bucket = " << new_bucket << endl;
  }

  bucket_idx = NUM_BUCKETS - 1;
  idx = 0;
  num_promotions = 0;
  repeat_promotion = false;
  while (num_promotions < MAX_NUM_PROMOTIONS) {
    base = buckets[bucket_idx][idx];
    cout << "\tbase = " << hex << base << ", " << ema[base] << dec << ", bucket = " << bucket_idx << endl;

    if (hawkeye_promotions.find(base) == hawkeye_promotions.end()) {
        hawkeye_promotions[base] = 0;
    } else {
      hawkeye_promotions[base]++;
      repeat_promotion = true;
    }

    idx++;
    while (bucket_idx >= 0 && idx >= buckets[bucket_idx].size()) {
      idx = 0;
      bucket_idx--;
    }
    if (bucket_idx < 0) {
      cout << "PROMOTED ALL DATA!" << endl;
      break;
    }
    if (!repeat_promotion) num_promotions++;
    repeat_promotion = false;
  }
}

void hawkeye_track_access(uint64_t vaddr) {
  uint64_t base, page, offset;

  curr_num_accesses++;
  total_num_accesses++;

  if (!tracking) {
    if (curr_num_accesses % (FACTOR*ACCESS_INTERVAL) == 0) {
        tracking = true;
        curr_num_accesses = 0;
    }
    return;
  }

  page = (uint64_t) (vaddr/PAGE_SIZE);
  base = (uint64_t) (vaddr/HUGE_PAGE_SIZE);
  offset = page - base*(HUGE_PAGE_SIZE/PAGE_SIZE);

  if (coverage.find(base) == coverage.end()) coverage[base] = bitset<NUM_BASE_PAGES>(0);
  coverage[base].set(offset, true);

  if (curr_num_accesses % ACCESS_INTERVAL == 0) {
    summarize();
    clear_coverage();
    tracking = false;
    curr_num_accesses = 0;
  }
}