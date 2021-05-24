/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "fragutils.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <pthread.h>
#include <stddef.h>
#include <string.h>

// Nobody ever use -DNDEBUG so we better control this our selves
#if 1
#include <assert.h>
#define SANITY_CHECK
#else
#define assert(x)
#endif

#define MS 1000000				/* One milli second in nanos */

#define REFINC(x) __atomic_add_fetch(&(x),1,__ATOMIC_SEQ_CST)
#define REFDEC(x) __atomic_sub_fetch(&(x),1,__ATOMIC_SEQ_CST)
#define MUTEX(x) pthread_mutex_t x
#define LOCK(x) pthread_mutex_lock(x)
#define UNLOCK(x) pthread_mutex_unlock(x)
#define MUTEX_DESTROY(x) pthread_mutex_destroy(x)
#define MUTEX_INIT(x) pthread_mutex_init(x, NULL);

/* ----------------------------------------------------------------------
 */

/*
  Holds data necessary to store hash values and fragments to re-inject
  in the ct. A pointer to this structure is passed as "user_ref" to
  ctCreate() and is passed back as the firsts parameter in call-backs.
 */
struct CtObj {
	struct ct* ct;
	struct ItemPool* fragDataPool; /* Items actually stored in the ct */
	struct ItemPool* bucketPool;   /* Extra buckets on hash collisions */
	struct ItemPool* fragmentPool; /* Stored not-first fragments to re-inject */
};

/*
  FragData objects are stored in the ct. Since these are returned in a
  ctLookup() we must ensure that the object is not released by another
  thread while the ctLookup() caller is using it. So, a
  reference-counter is used.
 */
struct FragData {
	int referenceCounter;
	int firstFragmentSeen;		/* Meaning the hash is valid */
	unsigned hash;
	MUTEX(mutex);				/* For "storedFragments" */
	struct Item* storedFragments;
};

// user_ref may be NULL
static void fragDataLock(void* user_ref, void* data)
{
	struct FragData* f = data;
	REFINC(f->referenceCounter);
}
// user_ref may be NULL
static void fragDataUnlock(void* user_ref, void* data)
{
	struct FragData* f = data;
	if (REFDEC(f->referenceCounter) <= 0) {
		/*
		  If the FragData object is released due to a timeout there
		  may be stored fragments lingering. Normally these should
		  have been re-injected and freed by now.
		 */
		itemFree(f->storedFragments);
		struct Item* item = ITEM_OF(data);
		itemFree(item);
	}
}
/*
  Lookup or create a FragData object.
  return;
  NULL - No more buckets (or something really weird)
  != NULL - FragData. The calling function *must* call fragDataUnlock!
*/
static struct FragData* fragDataLookup(
	struct CtObj* ctobj, struct timespec* now, struct ctKey const* key)
{
	struct FragData* f = ctLookup(ctobj->ct, now, key);
	// if != NULL the reference-counter has been incremented
	if (f == NULL) {
		// Did not exist. Allocate it from the fragDataPool
		struct Item* i = itemAllocate(ctobj->fragDataPool);
		if (i == NULL)
			return NULL;
		f = (struct FragData*) i->data;
		f->referenceCounter = 1; /* Only the CT refer the object */
		f->firstFragmentSeen = 0;
		f->storedFragments = NULL;

		switch (ctInsert(ctobj->ct, now, key, f)) {
		case 0:
			// Make it look like a succesful ctLookup()
			REFINC(f->referenceCounter);
			break;
		case 1:
			/*
			  Another thread has also allocated the entry and we lost
			  the race. Yeld, and use the inserted object.
			 */
			fragDataUnlock(ctobj, f); /* will release our allocated object */
			f = ctLookup(ctobj->ct, now, key);
			if (f == NULL) {
				/*
				  The object created by another thread has been
				  deleted again! This should not happen. Give up.
				 */
				return NULL;
			}
			break;
		default:
			/*
			  Failed to allocate a bucket in the ct. Our FragData is
			  locked with referenceCounter=1, call fragDataUnlock() to
			  release it.
			 */
			fragDataUnlock(ctobj, f);
			return NULL;
		}
	}
	return f;
}



/*
  bucketPoolAllocate() and bucketPoolFree() are passed in ctCreate().
  When a hash collision occurs in the ct it must allocate a new hash
  bucket. This *only* occurs is several packets gets the same fragment
  hash. This should normally be extremly rare and if it happens it
  could be a DoS attack. Because of that we can't just do "malloc" so
  a "bucket-pool" is used.
 */
static void* bucketPoolAllocate(void* user_ref)
{
	struct CtObj* ctobj = user_ref;
	struct Item* i = itemAllocate(ctobj->bucketPool);
	if (i == NULL)
		return NULL;
	return i->data;
}
static void bucketPoolFree(void* user_ref, void* b)
{
	struct Item* item = ITEM_OF(b);
	itemFree(item);
}

/* ----------------------------------------------------------------------
*/

static struct CtObj ctobj = {0};

static void initMutex(struct Item* item)
{
	struct FragData* f = (struct FragData*)(item->data);
	MUTEX_INIT(&f->mutex);
}

void fragInit(
	unsigned hsize,
	unsigned maxBuckets,
	unsigned maxFragments,
	unsigned mtu,
	unsigned timeoutMillis)
{
	if (ctobj.ct != NULL)
		return;
	ctobj.bucketPool = itemPoolCreate(maxBuckets, sizeof_bucket, NULL);
	ctobj.fragmentPool = itemPoolCreate(maxFragments, mtu, NULL);
	// In theory we can have max (hsize + maxBuckets) FragData objects in the ct
	ctobj.fragDataPool = itemPoolCreate(
		hsize + maxBuckets, sizeof(struct FragData), initMutex);
	ctobj.ct = ctCreate(
		hsize, timeoutMillis * MS, fragDataUnlock, fragDataLock,
		bucketPoolAllocate, bucketPoolFree, &ctobj);
	assert(ctobj.ct != NULL);
}

int fragInsertFirst(
	struct timespec* now, struct ctKey* key, unsigned hash)
{
	struct FragData* f = fragDataLookup(&ctobj, now, key);
	if (f == NULL) {
		return -1;				/* Out of buckets */
	}
	// Lock here to avoid a race with fragGetHashOrStore()
	LOCK(&f->mutex);
	f->hash = hash;
	f->firstFragmentSeen = 1;
	UNLOCK(&f->mutex);
	fragDataUnlock(NULL, f);
	return 0;					/* OK return */
}

struct Item* fragGetStored(struct timespec* now, struct ctKey* key)
{
	struct FragData* f = ctLookup(ctobj.ct, now, key);
	if (f == NULL)
		return NULL;

	struct Item* storedFragments;
	LOCK(&f->mutex);
	storedFragments = f->storedFragments;
	f->storedFragments = NULL;
	UNLOCK(&f->mutex);

	fragDataUnlock(NULL, f);
	return storedFragments;
}

int fragGetHash(struct timespec* now, struct ctKey* key, unsigned* hash)
{
	struct FragData* f = ctLookup(ctobj.ct, now, key);
	if (f == NULL || !f->firstFragmentSeen) {
		return -1;
	}
	*hash = f->hash;
	fragDataUnlock(NULL, f);
	return 0;
}

int fragGetHashOrStore(
	struct timespec* now, struct ctKey* key, unsigned* hash,
	void* data, unsigned len)
{
	struct FragData* f = fragDataLookup(&ctobj, now, key);
	if (f == NULL) {
		return -1;				/* Out of buckets */
	}
	if (f->firstFragmentSeen) {
		*hash = f->hash;
		fragDataUnlock(NULL, f);
		return 0;				/* OK return */
	}

	/*
	  We have not seen the first fragment. Store this fragment.
	 */
	struct ItemPoolStats const* stats = itemPoolStats(ctobj.fragmentPool);
	if (len > stats->itemSize) {
		fragDataUnlock(NULL, f);
		return -1;				/* Fragment > MTU ?? */
	}

	struct Item* item = itemAllocate(ctobj.fragmentPool);
	if (item == NULL) {
		fragDataUnlock(NULL, f);
		return -1;				/* Out of fragment space */
	}

	item->len = len;
	memcpy(item->data, data, len);

	int rc;
	LOCK(&f->mutex);
	if (f->firstFragmentSeen) {
		/*
		 The first-fragment has arrived in another thread while we
		 were working.  This race should be rare. Do NOT keep the
		 mutex for longer than needed.
		*/
		rc = 0;
	} else {
		item->next = f->storedFragments;
		f->storedFragments = item;
		rc = 1;
	}
	UNLOCK(&f->mutex);

	if (rc == 0) {
		*hash = f->hash;
		// Release no-longer-needed Item outside the lock
		itemFree(item);
	}

	fragDataUnlock(NULL, f);
	return rc;
}

void fragGetStats(struct timespec* now, struct fragStats* stats)
{
	/*
	  To call ctStats() will trig a full GC. I.e. call-backs to
	  fragDataUnlock for timed-out FragData objects.
	 */
	struct ctStats const* ctstats = ctStats(ctobj.ct, now);

	stats->ttlMillis = ctstats->ttlNanos / MS;
	stats->size = ctstats->size;
	stats->active = ctstats->active;
	stats->collisions = ctstats->collisions;
	stats->inserts = ctstats->inserts;
	stats->rejectedInserts = ctstats->rejectedInserts;
	stats->lookups = ctstats->lookups;
	stats->objGC = ctstats->objGC;

	struct ItemPoolStats const* istats;
	istats = itemPoolStats(ctobj.bucketPool);
	stats->maxBuckets = istats->size;
	istats = itemPoolStats(ctobj.fragmentPool);
	stats->maxFragments = istats->size;
	stats->mtu = istats->itemSize;
	istats = itemPoolStats(ctobj.fragmentPool);
	stats->storedFrags = istats->size - istats->nFree;

#ifdef SANITY_CHECK
	istats = itemPoolStats(ctobj.fragDataPool);
	assert(ctstats->active == (istats->size - istats->nFree));
	assert(stats->size == (istats->size - stats->maxBuckets));

	istats = itemPoolStats(ctobj.bucketPool);
	assert(ctstats->collisions == (istats->size - istats->nFree));
#endif
}


