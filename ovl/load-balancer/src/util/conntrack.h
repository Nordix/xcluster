/*
  SPDX-License-Identifier: MIT License
  Copyright (c) 2021 Nordix Foundation
*/

/*
  A simple connection/fragment tracker

  Implemented as a hash table with addresses+id or the 5-tuple
  {proto,srcAddr,dstAddr,srcPort,dstPort} as key.

  Bucket allocation

  If there are no hash collisions no buckets are allocated. On a
  collision the user defined "allocBucketFn" is called. It should
  return a pointer to memory of "sizeof_bucket" bytes or NULL. If NULL
  is returned the "ctInsert" will fail and return -1.

  User data handling

  The connection handles (void*) pointers. When a bucket has timed out
  or when "ctRemove" is called the "freefn" is called for the
  data. The used should not free the data until "freefn" is
  called. The "freeFn" is only called once for each user data.

  A Garbage Collection procedure is used. User data for timed out
  buckets is not freed until the bucket is re-used or when "ctStats"
  is called which trigs a full GC.

  A "lockfn" may be specified which will be called for the user data
  while the bucket is locked. This can be used for exclusive use when
  multiple threads may call "ctLookup" or "ctRemove"
 */



#include <stdint.h>
#include <netinet/in.h>

// Hash key
typedef uint32_t ctCounter;
struct ctKey {
	// For IPv4 use ipv4 encoded addresses like ::ffff:10.0.0.1
	struct in6_addr src;
	struct in6_addr dst;
	union {
		uint64_t id;
		struct {
			uint16_t user_defined;
			uint16_t proto;
			uint16_t src;
			uint16_t dst;
		} ports;
	};
};

struct ctStats {
	ctCounter size;				/* Size of the hash table */
	ctCounter active;			/* Connections currently in use */
	ctCounter collisions;		/* Bucket collisions counter */
	ctCounter inserts;			/* Insert counter */
	ctCounter rejectedInserts;	/* Rejected insert counter */
	ctCounter lookups;			/* Lookup counter */
};


typedef void (*ctFree)(void* data);
typedef void (*ctLock)(void* data);
typedef void* (*ctAllocBucket)(void); /* Return "sizeof_bucket" bytes or NULL */
extern size_t sizeof_bucket;

struct ct* ctCreate(
	ctCounter hsize,
	uint64_t ttlNanos,
	/*
	  The "freefn" MUST NOT block or call other conntrack
	  functions! The bucket is locked during the call an to do so may
	  cause starvation or a dead-lock.
	*/
	ctFree freeDataFn,
	ctLock lockDataFn,
	ctAllocBucket allocBucketFn,
	ctFree freeBucketFn);

/*
  There is nothing that prevents the returned data from beeing removed
  from the conntracker at any time after the call. Some other thread
  may call "ctRemove" for instance. The user should use the
  "lockDataFn" and "freeDataFn" functions to cope with this. Maybe
  with reference counters.
*/
void* ctLookup(
	struct ct* ct, struct timespec* now, struct ctKey const* key);

/*
  ctFree is only called in succesful insert.
  Return;
   0 - Success, Data inserted, ctFree will be called.
   1 - Busy, data for this key exists already. Make a ctLookup and update.
  -1 - Failed, bucket allocation failed.
*/
int ctInsert(
	struct ct* ct, struct timespec* now, struct ctKey const* key, void* data);

void ctRemove(
	struct ct* ct, struct timespec* now, struct ctKey const* key);

/*
 This function will lock and scan the entire hash table. It will trig
 a full GC. Use it with caution!
*/
struct ctStats const* ctStats(
	struct ct* ct, struct timespec* now);

// Will hang until everything is unlocked
void ctDestroy(struct ct* ct);
