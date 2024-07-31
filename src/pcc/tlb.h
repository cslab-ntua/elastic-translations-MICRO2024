#include <map>
#include <unordered_map>
#include <vector>
#include <set>
#include <bitset>
#include <math.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <algorithm>
#include <stdlib.h>
#include <time.h>
#include <assert.h>

#define L1_TLB_4K_ENTRIES 64
#define L1_TLB_2M_ENTRIES 32
#define L2_TLB_ENTRIES 1024
#define PAGE_SIZE 4096
#define HUGE_PAGE_SIZE 2097152
#define L1_ASSOC 4
#define L2_ASSOC 6
#define MAX_FREQ 255

using namespace std;

struct CacheLine {
  uint64_t addr;
  uint64_t offset;
  CacheLine* prev;
  CacheLine* next;
  bool dirty=false;
  
  unsigned short freq=0;
};

class CacheSet {
public:
  CacheLine *head;
  CacheLine *tail;
  CacheLine *entries;
  std::vector<CacheLine*> freeEntries;
  std::unordered_map<uint64_t, CacheLine*> addr_map;

  unsigned int associativity;
  int line_size;
  unsigned policy;

  CacheSet(int size, int cache_line_size, unsigned int eviction_policy) {
    associativity = size;
    line_size = cache_line_size;
    policy = eviction_policy;

    CacheLine *c;
    entries = new CacheLine[associativity];
    for(unsigned int i=0; i<associativity; i++) {
      c = &entries[i];
      freeEntries.push_back(c);
    }
    head = new CacheLine;
    tail = new CacheLine;
    head->prev = NULL;
    head->next = tail;
    tail->next = NULL;
    tail->prev = head;
  }
  ~CacheSet() {
    delete head;
    delete tail;
    delete [] entries;
  }

  bool access(uint64_t address, uint64_t offset, bool isLoad) {
    CacheLine* c = addr_map[address];
    if(c) { // Hit
      deleteNode(c);
      if (policy == 0) {
        insertFront(c, head);
      } else if (policy == 1) {
        if (c->freq >= associativity/2) insertFront(c, head);
      } else if (policy == 2) {
        insertLFU(c, head);
      }

      if(!isLoad)
        c->dirty = true;
      c->offset = offset;
      c->freq++;
      if (c->freq == MAX_FREQ) decay_freqs();

      return true;
    } else {
      return false;
    }
  }

  void insert(uint64_t address, uint64_t offset, bool isLoad, bool *dirtyEvict, int64_t *evictedAddr, uint64_t *evictedOffset) {
    CacheLine *c = addr_map[address];
    bool eviction = freeEntries.size() == 0;

    if (eviction) {
      c = tail->prev; // LRU
      assert(c!=head);

      addr_map.erase(c->addr); // removing tag
      *evictedAddr = c->addr;
      *evictedOffset = c->offset;
      *dirtyEvict = c->dirty;
      deleteNode(c);
    } else { // there is space, no need for eviction
      c = freeEntries.back();
      freeEntries.pop_back();
    }

    addr_map[address] = c; // insert into address map
    c->addr = address;
    c->offset = offset;
    c->dirty = !isLoad; // write-back cache insertion
    c->freq = 0;

    if (policy == 0) insertFront(c, head); // LRU for insertion
    else if (policy == 1) insertHalf(c, head); // insert halfway into set
    else if (policy == 2) insertLFU(c, head); // insert by frequency
  }

  void evict(uint64_t address, bool *dirtyEvict) {
    CacheLine *c = addr_map[address];
    assert(c!=head);
    
    addr_map.erase(c->addr); // removing tag
    *dirtyEvict = c->dirty;
    deleteNode(c);
    freeEntries.push_back(c);
  }

  unsigned short get_freq(uint64_t address) {
    assert(addr_map.find(address) != addr_map.end());
    
    CacheLine *c = addr_map[address];
    assert(c!=head);

    return (c->freq);
  }

  void decay_freqs() {
    CacheLine *c = head->next;
    while (c != tail) {
      c->freq /= 2;
      c = c->next;
    }
  }

  void flush() {
    CacheLine *c = head->next;
    while (c != tail) {
      addr_map.erase(c->addr); // removing tag
      freeEntries.push_back(c);
      c = c->next;
      deleteNode(c->prev);
    }
  }

  void print() {
    CacheLine *c = head->next;
    while (c != tail) {
      cout << c->addr << " ";
      //cout << c->addr << endl;
      c = c->next;
    }
    cout << endl;
  }

  void get_set(vector<uint64_t> *addresses) {
    CacheLine *c = head->next;
    while (c != tail) {
      addresses->push_back(c->addr);
      c = c->next;
    }
  }

  // Insert such that MRU is first
  void insertFront(CacheLine *c, CacheLine *currHead){
    c->next = currHead->next;
    c->prev = currHead;
    currHead->next = c;
    c->next->prev = c;
  }
  
  // Insert such that MRU is mid-way
  void insertHalf(CacheLine *c, CacheLine *currHead){
    unsigned int idx = 0, num_entries = associativity - freeEntries.size(), end = 0;
    CacheLine *curr = head->next;
    
    if (num_entries == associativity) end = (unsigned int) associativity/2; 
    else end = (unsigned int) (num_entries/2); // insert halfway

    while (idx < end && curr != tail) {
      curr = curr->next;
      idx++;
    }
     
    c->next = curr;
    c->prev = curr->prev;
    curr->prev = c;
    c->prev->next = c;
  }

  void insertLFU(CacheLine *c, CacheLine *currHead){
    CacheLine *curr = head->next;
    
    while (c->freq < curr->freq) {
      curr = curr->next;
    }
     
    c->next = curr;
    c->prev = curr->prev;
    curr->prev = c;
    c->prev->next = c;
  }

  void deleteNode(CacheLine *c) {
    assert(c->next);
    assert(c->prev);
    c->prev->next = c->next;
    c->next->prev = c->prev;
  }
};

class FunctionalCache {
public:
  int line_count;
  int set_count;
  int log_set_count;
  int cache_line_size;
  int log_line_size;
  vector<CacheSet*> sets;

  FunctionalCache(unsigned long size, int assoc, int line_size, unsigned int eviction_policy=0)
  {
    cache_line_size = line_size;
    line_count = size / cache_line_size;
    set_count = line_count / assoc;
    log_set_count = log2(set_count);
    log_line_size = log2(cache_line_size);

    for(int i=0; i < set_count; i++)
    {
      CacheSet* set = new CacheSet(assoc, cache_line_size, eviction_policy);
      sets.push_back(set);
    }
  }

  uint64_t extract(int max, int min, uint64_t address) // inclusive
  {
      uint64_t maxmask = ((uint64_t)1 << (max+1))-1;
      uint64_t minmask = ((uint64_t)1 << (min))-1;
      uint64_t mask = maxmask - minmask;
      uint64_t val = address & mask;
      val = val >> min;
      return val;
  }

  bool access(uint64_t address, bool isLoad, bool is2M=false, bool print=false)
  {
    int log_pofs = is2M ? log2(HUGE_PAGE_SIZE) : log_line_size;
    uint64_t offset = extract(log_pofs-1, 0, address);
    uint64_t setid = extract(log_set_count+log_pofs-1, log_pofs, address);
    uint64_t tag = extract(63, log_set_count+log_pofs, address);
    CacheSet *c = sets.at(setid);
  
    bool res = c->access(tag, offset, isLoad);
    if (print) cout << "Accessing " << address << "; tag = " << tag << ", setid = " << setid << ", offset = " << offset << " --> " << res << endl;

    return res;
  }

  void insert(uint64_t address, bool isLoad, bool *dirtyEvict, int64_t *evictedAddr, uint64_t *evictedOffset, bool is2M=false, bool print=false)
  {
    int log_pofs = is2M ? log2(HUGE_PAGE_SIZE) : log_line_size;
    uint64_t offset = extract(log_pofs-1, 0, address);
    uint64_t setid = extract(log_set_count-1+log_pofs, log_pofs, address);
    uint64_t tag = extract(63, log_set_count+log_pofs, address);
    CacheSet *c = sets.at(setid);
    int64_t evictedTag = -1;
    *dirtyEvict = false;

    c->insert(tag, offset, isLoad, dirtyEvict, &evictedTag, evictedOffset);
    if (print) cout << "Inserting " << address << "; tag = " << tag << ", setid = " << setid << ", offset = " << offset << endl;

    if(evictedAddr && evictedTag != -1) {
      *evictedAddr = evictedTag * set_count + setid;
    }
  }

  void evict(uint64_t address, bool *dirtyEvict, bool is2M=false, bool print=false)
  {
    int log_pofs = is2M ? log2(HUGE_PAGE_SIZE) : log_line_size;
    uint64_t offset = extract(log_pofs-1, 0, address);
    uint64_t setid = extract(log_set_count-1+log_pofs, log_pofs, address);
    uint64_t tag = extract(63, log_set_count+log_pofs, address);
    CacheSet *c = sets.at(setid);
    *dirtyEvict = false;

    c->evict(tag, dirtyEvict);
    if (print) cout << "Evicting " << address << "; tag = " << tag << ", setid = " << setid << ", offset = " << offset << endl;
  }

  unsigned short getFreq(uint64_t address, bool is2M=false)
  {
    int log_pofs = is2M ? log2(HUGE_PAGE_SIZE) : log_line_size;
    uint64_t setid = extract(log_set_count-1+log_pofs, log_pofs, address);
    uint64_t tag = extract(63, log_set_count+log_pofs, address);
    CacheSet *c = sets.at(setid);

    return c->get_freq(tag);
  }

  void flush() {
    for(int i=0; i < set_count; i++) {
      sets[i]->flush();
    }
  }

  void print() {
    for(int i=0; i < set_count; i++) {
      cout << "Set " << i << ":\n";
      sets[i]->print();
    }
  }
  
  vector<uint64_t> get_entries() {
    vector<uint64_t> addresses;
    for(int i=0; i < set_count; i++) {
      sets[i]->get_set(&addresses);
    }
    return addresses;
  }
};
