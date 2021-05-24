/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "itempool.h"
#include "conntrack.h"

/*
  TCP uses PMTU to avoid fragmentation so fragmentation normally only
  happens for other protocols like UDP.

  About sizes

  It is of course impossible to give a definite answer, but there are
  some things to consider.

  The theoretical max of fragment entries is (hsize + maxBuckets). But
  hashing is not perfect so a better estimate is (hsize * used% + maxBuckets).
  The used% depends on the data and the quality of the hash function.

  The larger the hsize, the lower the probablility for collisions and
  therefore better performance. maxBuckets is only needed on hash
  collisions but they may happen even on low usage if we are unlucky.

  A rule of thumb may be to set hsize to x2 the estimated concurrent
  fragmented packets and always set maxBuckets equal to hsize.

  Fragments out-of-order should be extremely rare. A conservative
  value for maxFragments may be ok. Even 0 (zero) if we don't care.

  MTU is the maximum size of stored fragments. It should be set to the
  MTU size for the ingress device.

  About timeout and GC

  The timeout should be set fairly low, e.g. 200ms. This is a
  fragmented packet we are talking about, not some re-send
  timeout. There is a standard saying 2sec I think, but don't care
  about that. Remember that we never exlpicitly remove anything from
  the fragment table, *everything* is removed by a timeout!

  Fragment entries that has timed out are not automatically
  freed. Instead they are GC'ed when a bucket is re-used. If there are
  no collisions it will always work with no overhead. We have
  optimized for the normal case.

  But if we have got collisions and allocated new bucket structures
  they will linger until next time we happen to hash to that same
  bucket (which may be never). This should work fairly well over time
  since buckets will most often be re-used eventually, and in case of
  high load, more frequently.

  However a full GC is trigged by reading the fragmentation stats. So
  it may be prudent to do so from time to time. A reason may be for
  metrics or for an alarm on over-use of stored fragments which may
  indicate a DoS attack.

*/
void fragInit(
	unsigned hsize,				/* Hash-table size */
	unsigned maxBuckets,		/* on top of hsize */
	unsigned maxFragments,		/* Max non-first fragments to store */
	unsigned mtu,				/* Max size of stored fragments */
	unsigned timeoutMillis);	/* Timeout for fragments */

/*
  Inserts the first fragment and stores the passed hash to be used for
  sub-sequent fragments.
  return:
   0 - Hash stored
  -1 - Failed to store hash
*/
int fragInsertFirst(
	struct timespec* now, struct ctKey* key, unsigned hash);

/*
  Called for non-first fragments.
  return:
   0 - Hash is valid. Fragment is not stored.
   1 - Hash is NOT valid. The fragment is stored.
  -1 - Hash is NOT valid. Failed to store the fragment.
*/
int fragGetHashOrStore(
	struct timespec* now, struct ctKey* key, unsigned* hash,
	void* data, unsigned len);

/*
  Called for non-first fragments when we don't want to store the fragment.
  Returns: hash
  return:
   0 - Hash is valid.
  -1 - Hash is NOT valid.
*/
int fragGetHash(struct timespec* now, struct ctKey* key, unsigned* hash);


struct Fragment {
	struct Fragment* next;
	void* data;
	unsigned len;
};

/*
  Get stored fragments
  return:
  NULL - No fragments found
*/
struct Fragment* fragGetStored(struct timespec* now, struct ctKey* key);

/*
  Free fragments returned by fragGetStored(). Passing NULL is OK.
*/
void fragFree(struct Fragment* frags);


struct fragStats {
	// Conntrack stats
	unsigned active;
	unsigned collisions;
	unsigned inserts;
	unsigned rejectedInserts;
	unsigned lookups;
	// Frag stats
	unsigned allocatedFrags;
	unsigned storedFrags;
};

void fragGetStats(struct timespec* now, struct fragStats* stats);
