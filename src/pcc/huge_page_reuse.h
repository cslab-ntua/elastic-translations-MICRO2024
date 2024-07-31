#include "tlb.h"
#include <boost/tuple/tuple.hpp>

#define EVICTION_POLICY 2
#define TRACK_REUSE 1

unordered_map<uint64_t, boost::tuple<unsigned long, double, unsigned long, double>> reuse_map;
unordered_map<uint64_t, unsigned short> pcc_promotions;

FunctionalCache *l1_tlb_4k, *l1_tlb_2m, *l2_tlb, *promotion_cache;
bool l1_4k_dirty_evict, l1_2m_dirty_evict, l2_dirty_evict;
int64_t l1_4k_evicted_tag, l1_2m_evicted_tag, l2_evicted_tag;
uint64_t l1_4k_evicted_offset, l1_2m_evicted_offset, l2_evicted_offset, evicted_addr;

void promotion_cache_init() {
  l1_tlb_4k = new FunctionalCache(L1_TLB_4K_ENTRIES*PAGE_SIZE, L1_ASSOC, PAGE_SIZE);
  l1_tlb_2m = new FunctionalCache(L1_TLB_2M_ENTRIES*HUGE_PAGE_SIZE, L1_ASSOC, HUGE_PAGE_SIZE);
  l2_tlb = new FunctionalCache(L2_TLB_ENTRIES*PAGE_SIZE, L2_ASSOC, PAGE_SIZE);
  l1_4k_dirty_evict = l1_2m_dirty_evict = l2_dirty_evict = false;
  l1_4k_evicted_tag = l1_2m_evicted_tag = l2_evicted_tag = -1;
  l1_4k_evicted_offset = l1_2m_evicted_offset = l2_evicted_offset = 0;
  
  promotion_cache = new FunctionalCache(PROMOTION_CACHE_SIZE*PAGE_SIZE, PROMOTION_CACHE_SIZE, PAGE_SIZE, EVICTION_POLICY);
}

void summarize_promotions() {
  unsigned long base, freq, cache_freq, addr;
  double reuse_dist;
  bool res;
  vector<uint64_t> addresses = promotion_cache->get_entries();

  cout << "\n" << dec << total_num_accesses << ": Memory Regions:" << endl;
  for (unsigned long i = 0; i < addresses.size(); i++) {
    base = addresses[i];
    freq = boost::get<2>(reuse_map[base]);
    reuse_dist = boost::get<3>(reuse_map[base]);
    cache_freq = promotion_cache->getFreq(base*PAGE_SIZE);
    cout << "\tbase = " << hex << base << dec << ", " << reuse_dist << ", " << freq << ", " << cache_freq;
        
    if (pcc_promotions.find(base) == pcc_promotions.end() && cache_freq > 0) { // promoting data that is not already promoted
        pcc_promotions[base] = 0;
	      reuse_map.erase(base);
	      for (int i = 0; i < HUGE_PAGE_SIZE/PAGE_SIZE; i++) {
	          addr = base*HUGE_PAGE_SIZE + i*PAGE_SIZE;
	          res = l1_tlb_4k->access(addr, true, false);
            if (res) l1_tlb_4k->evict(addr, &l1_4k_dirty_evict, false);
            res = l2_tlb->access(addr, true, false);
	          if (res) l2_tlb->evict(addr, &l2_dirty_evict);
        }
    } else if (pcc_promotions.find(base) != pcc_promotions.end()) { // demotion
      //pcc_promotions[base]++;
      cout << "--> DEMOTION";
      pcc_promotions.erase(base);
      addr = base*HUGE_PAGE_SIZE + i*PAGE_SIZE;
      res = l1_tlb_2m->access(addr, true, true);
      if (res) l1_tlb_2m->evict(addr, &l1_2m_dirty_evict, true);
      res = l2_tlb->access(addr, true, true);
      if (res) l2_tlb->evict(addr, &l2_dirty_evict, true);
    }
    cout << endl;
    promotion_cache->evict(base*PAGE_SIZE, &l1_2m_dirty_evict);
  }
}

void pcc_track_access(uint64_t vaddr, bool print=false) {
    uint64_t base;

    total_num_accesses++;
    
    if ((FACTOR > 1) && (total_num_accesses % (FACTOR*ACCESS_INTERVAL) == ACCESS_INTERVAL)) {
      summarize_promotions();
    } else if (total_num_accesses % (FACTOR*ACCESS_INTERVAL) == 0) {
      summarize_promotions();
    } 
    base = (uint64_t) (vaddr/HUGE_PAGE_SIZE);

    /********** START: TLB hierarchy logic **********/
    bool l1_4k_hit, l1_2m_hit, l2_hit, is_2m;

    l1_4k_hit = l1_tlb_4k->access(vaddr, true);
    l1_2m_hit = l1_tlb_2m->access(vaddr, true);
    if (!l1_4k_hit && !l1_2m_hit) { // L1 TLB miss
        l2_hit = l2_tlb->access(vaddr, true, false);
        if (!l2_hit) { // L2 4K TLB miss
            l2_hit = l2_tlb->access(vaddr, true, true);

	    if (!l2_hit) { // L2 2M TLB miss
	        is_2m = pcc_promotions.find(base) != pcc_promotions.end(); // promoted
                l2_tlb->insert(vaddr, true, &l2_dirty_evict, &l2_evicted_tag, &l2_evicted_offset, is_2m);

                if (is_2m) {
                    l1_tlb_2m->insert(vaddr, true, &l1_2m_dirty_evict, &l1_2m_evicted_tag, &l1_2m_evicted_offset);
	        } else {	    
                    l1_tlb_4k->insert(vaddr, true, &l1_4k_dirty_evict, &l1_4k_evicted_tag, &l1_4k_evicted_offset);
		}
	    } else { // if L2 2M TLB hit, don't track reuse
                l1_tlb_2m->insert(vaddr, true, &l1_2m_dirty_evict, &l1_2m_evicted_tag, &l1_2m_evicted_offset);
                return;
	    }
	} else { // if L2 4K TLB hit, don't track reuse
            l1_tlb_4k->insert(vaddr, true, &l1_4k_dirty_evict, &l1_4k_evicted_tag, &l1_4k_evicted_offset);
            return;
	}
        l1_tlb_4k->insert(vaddr, true, &l1_4k_dirty_evict, &l1_4k_evicted_tag, &l1_4k_evicted_offset);
    } else { // if L1 TLB hit, don't track reuse
        return;
    }
    /********** END: TLB hierarchy logic **********/

    bool res;
    if (reuse_map.find(base) == reuse_map.end()) { // cold L1 TLB miss won't have reuse tracked anyway
      reuse_map[base] = boost::make_tuple(0, 0, 0, 0);
      return;
    } else {
      /********** START: promotion cache logic **********/
      is_2m = pcc_promotions.find(base) != pcc_promotions.end();
      res = promotion_cache->access(base*PAGE_SIZE, true, is_2m);
      if (!res) {
	      if (is_2m && boost::get<0>(reuse_map[base]) != 0) num_2mb_ptw++; //cout << base << " --> 2MB PTW" << endl;
	      promotion_cache->insert(base*PAGE_SIZE, true, &l1_4k_dirty_evict, &l1_4k_evicted_tag, &l1_4k_evicted_offset, is_2m);
	      if (l1_4k_evicted_tag != -1) {
          evicted_addr = (l1_4k_evicted_tag*PAGE_SIZE + l1_4k_evicted_offset)/PAGE_SIZE;
          reuse_map[evicted_addr] = boost::make_tuple(0, 0, 0, 0); // lose information if evicted
	      }
      }
      /********** END: promotion cache logic **********/ 

#ifdef TRACK_REUSE
    uint64_t reuse_dist, num_data_pts;
    double ema, sum_sq, std_dev;
      if (boost::get<0>(reuse_map[base]) == 0) { // first tracking
          boost::get<0>(reuse_map[base]) = total_num_accesses;
	  return;
      }

      reuse_dist = total_num_accesses - boost::get<0>(reuse_map[base]); // current reuse dist
      sum_sq = boost::get<1>(reuse_map[base]); // current sum of differences (reuse dist - EMA)
      num_data_pts = boost::get<2>(reuse_map[base]); // num of reuse dists
      ema = boost::get<3>(reuse_map[base]); // current mean (EMA)
      std_dev = sqrt(sum_sq/num_data_pts); // current std dev

      if (print) cout << reuse_dist 
			<< ": EMA = " << ema 
			<< ", std dev = " << std_dev 
			<< "; sum = " << sum_sq 
			<< ", n = " << num_data_pts 
			<< ", diff = " << (reuse_dist-ema) << endl;

      if (ema == 0) ema = reuse_dist;
      else ema = ema*ALPHA + reuse_dist*(1-ALPHA);
      sum_sq += pow((ema-reuse_dist), 2);
      num_data_pts++;

      boost::get<0>(reuse_map[base]) = total_num_accesses;
      boost::get<1>(reuse_map[base]) = sum_sq;
      boost::get<2>(reuse_map[base]) = num_data_pts;
      boost::get<3>(reuse_map[base]) = ema;
#endif
    }
}

void summarize_reuse() {
  unsigned long base;
  double reuse_dist, std_dev;

  if (total_num_accesses < ACCESS_INTERVAL) summarize_promotions();

  cout << "\nSummary:" << endl;
  unordered_map<uint64_t, boost::tuple<unsigned long, double, unsigned long, double>>::iterator reuse_map_it;
  for (reuse_map_it = reuse_map.begin(); reuse_map_it != reuse_map.end(); reuse_map_it++) {
    base = reuse_map_it->first;
    if (reuse_map.find(base) != reuse_map.end()) {
      reuse_dist = boost::get<3>(reuse_map[base]);
      std_dev = sqrt(boost::get<1>(reuse_map[base])/boost::get<2>(reuse_map[base]));
      if (reuse_dist == 0) continue;

      cout << hex << "\tbase = " << base 
		<< dec << ", reuse dist = " << reuse_dist 
		<< ", n = " << boost::get<2>(reuse_map[base]) 
		<< ", std dev = " << std_dev << endl;
    }
  }

  cout << "Promotion Cache\n";
  promotion_cache->print();
}
