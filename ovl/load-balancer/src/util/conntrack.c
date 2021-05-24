/*
  SPDX-License-Identifier: MIT License
  Copyright (c) 2021 Nordix Foundation
*/

#include "conntrack.h"
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#ifdef SINGLE_THREAD
#warning SINGLE_THREAD
#define MUTEX(x)
#define LOCK(x)
#define UNLOCK(x)
#define MUTEX_DESTROY(x)
#define ATOMIC_INC(x) ++(x)
#else
#include <pthread.h>
#define MUTEX(x) pthread_mutex_t x
#define LOCK(x) pthread_mutex_lock(x)
#define UNLOCK(x) pthread_mutex_unlock(x)
#define MUTEX_DESTROY(x) pthread_mutex_destroy(x)
#define ATOMIC_INC(x) __atomic_add_fetch(&(x),1,__ATOMIC_RELAXED)
#endif

extern uint32_t djb2_hash(uint8_t const* c, uint32_t len);
#define HASH djb2_hash

struct ctBucket {
	struct ctBucket* next;
	struct ctKey key;
	void* data;
	uint64_t refered;			/* Last time refered in nanoS */
	MUTEX(mutex);
};
struct ct {
	uint64_t ttl;
	ctFree freefn;
	ctLock lockfn;
	ctAllocBucket allocBucket;
	ctFree freeBucket;
	struct ctStats stats;
	struct ctBucket* bucket;
	void* user_ref;
};

size_t sizeof_bucket = sizeof(struct ctBucket);

static int keyEqual(struct ctKey const* key1, struct ctKey const* key2)
{
	return memcmp(key1, key2, sizeof(struct ctKey));
}
static uint64_t toNanos(struct timespec* t)
{
	return t->tv_sec * 1000000000 + t->tv_nsec;
}

// Remove stale entries. Returns number of active buckets
// The bucket must be locked on call.
static ctCounter
bucketGC(struct ct* ct, struct ctBucket* b, uint64_t nowNanos)
{
	ctCounter count = 0;
	if (b->data != NULL && (nowNanos - b->refered) > ct->ttl) {
		if (ct->freefn != NULL)
			ct->freefn(ct->user_ref, b->data);
		b->data = NULL;
		ATOMIC_INC(ct->stats.objGC);
	}
	if (b->data != NULL)
		count++;

	struct ctBucket* prev = b;
	struct ctBucket* item = prev->next;
	while (item != NULL) {
		if ((nowNanos - item->refered) > ct->ttl) {
			prev->next = item->next;
			if (item->data != NULL && ct->freefn != NULL)
				ct->freefn(ct->user_ref, item->data);
			ct->freeBucket(ct->user_ref, item);
			ATOMIC_INC(ct->stats.objGC);
		} else {
			prev = item;
			count++;
		}
		item = prev->next;
	}
	return count;
}

// The bucket is locked in the call.
static struct ctBucket* ctLookupBucket(
	struct ct* ct, uint64_t nowNanos, struct ctKey const* key)
{
	uint32_t hash = HASH((uint8_t const*)key, sizeof(*key));
	struct ctBucket* b = ct->bucket + (hash % ct->stats.size);
	LOCK(&b->mutex);

	/* Is the main bucket stale? */
	if (b->data != NULL && (nowNanos - b->refered) > ct->ttl) {
		if (ct->freefn != NULL)
			ct->freefn(ct->user_ref, b->data);
		b->data = NULL;
		ATOMIC_INC(ct->stats.objGC);
	}
	if (b->next != NULL) {
		/*
		  We have had collisions and have allocated additional
		  buckets. This is assumed to be a very rare case under normal
		  circumstances and could be indicating a DoS attack.
		 */
		bucketGC(ct, b, nowNanos);
	}
	return b;
}

struct ct* ctCreate(
	ctCounter hsize, uint64_t ttlNanos, ctFree freefn, ctLock lockfn,
	ctAllocBucket allocBucketFn, ctFree freeBucketFn, void* user_ref)
{
	if (allocBucketFn == NULL || freeBucketFn == NULL)
		return NULL;
	struct ct* ct = calloc(1, sizeof(*ct));
	if (ct == NULL)
		return NULL;
	ct->stats.size = hsize;
	ct->stats.ttlNanos = ttlNanos;
	ct->ttl = ttlNanos;
	ct->freefn = freefn;
	ct->lockfn = lockfn;
	ct->allocBucket = allocBucketFn;
	ct->freeBucket = freeBucketFn;
	ct->user_ref = user_ref;
	ct->bucket = calloc(hsize, sizeof(struct ctBucket));
	if (ct->bucket == NULL) {
		free(ct);
		return NULL;
	}
#ifndef SINGLE_THREAD
	for (ctCounter i = 0; i < hsize; i++) {
		pthread_mutex_init(&ct->bucket[i].mutex, NULL);
	}
#endif
	return ct;
}

void* ctLookup(
	struct ct* ct, struct timespec* now, struct ctKey const* key)
{
	uint64_t nowNanos = toNanos(now);
	struct ctBucket* B = ctLookupBucket(ct, nowNanos, key);
	ATOMIC_INC(ct->stats.lookups);
	struct ctBucket* b;
	for (b = B; b != NULL; b = b->next) {
		if (b->data != NULL && keyEqual(key, &b->key) == 0) {
			b->refered = nowNanos;
			if (ct->lockfn != NULL)
				ct->lockfn(ct->user_ref, b->data);
			UNLOCK(&B->mutex);
			return b->data;		/* Found! */
		}
	}
	UNLOCK(&B->mutex);
	return NULL;				/* Not found */
}
int ctInsert(
	struct ct* ct, struct timespec* now, struct ctKey const* key, void* data)
{
	if (data == NULL)
		return -1;				/* NULL indicates no-data */
	uint64_t nowNanos = toNanos(now);
	struct ctBucket* b = ctLookupBucket(ct, nowNanos, key);
	ATOMIC_INC(ct->stats.inserts);

	// Check if the entry already exists
	struct ctBucket* item;
	for (item = b; item != NULL; item = item->next) {
		if (item->data == NULL)
			continue;
		if (keyEqual(key, &item->key) == 0) {
			item->refered = nowNanos;
			UNLOCK(&b->mutex);
			return 1;				/* item exists already */
		}
	}

	if (b->data == NULL) {
		// The main bucket is free
		b->data = data;
		b->key = *key;
		b->refered = toNanos(now);
		if (b->next != NULL)
			ATOMIC_INC(ct->stats.collisions);
		UNLOCK(&b->mutex);
		return 0;
	}

	// We must allocate a new bucket
	ATOMIC_INC(ct->stats.collisions);
	struct ctBucket* x = ct->allocBucket(ct->user_ref);
	if (x == NULL) {
		ATOMIC_INC(ct->stats.rejectedInserts);
		UNLOCK(&b->mutex);
		return -1;
	}
	x->data = data;
	x->key = *key;
	x->refered = toNanos(now);
	x->next = b->next;
	b->next = x;
	UNLOCK(&b->mutex);
	return 0;
}

void ctRemove(
	struct ct* ct, struct timespec* now, struct ctKey const* key)
{
	uint64_t nowNanos = toNanos(now);
	struct ctBucket* b = ctLookupBucket(ct, nowNanos, key);
	if (keyEqual(key, &b->key) == 0) {
		if (b->data != NULL && ct->freefn != NULL)
			ct->freefn(ct->user_ref, b->data);
		b->data = NULL;
		UNLOCK(&b->mutex);
		return;
	}
	struct ctBucket* prev = b;
	struct ctBucket* item = prev->next;
	while (item != NULL) {
		if (keyEqual(key, &item->key) == 0) {
			prev->next = item->next;
			if (b->data != NULL && ct->freefn != NULL)
				ct->freefn(ct->user_ref, b->data);
			ct->freeBucket(ct->user_ref, item);
			break;
		} else {
			prev = item;
		}
		item = prev->next;
	}
	UNLOCK(&b->mutex);
}

// This function will scan the entire hash table. It will trig a full
// GC. Use it with caution!
struct ctStats const* ctStats(struct ct* ct, struct timespec* now)
{
	ctCounter active = 0;
	uint64_t nowNanos = toNanos(now);
	unsigned i;
	struct ctBucket* b = ct->bucket;
	for (i = 0; i < ct->stats.size; i++, b++) {
		LOCK(&b->mutex);
		active += bucketGC(ct, b, nowNanos);
		UNLOCK(&b->mutex);
	}
	ct->stats.active = active;
	return &ct->stats;
}
void ctDestroy(struct ct* ct)
{
	unsigned i;
	struct ctBucket* b = ct->bucket;
	for (i = 0; i < ct->stats.size; i++, b++) {
		LOCK(&b->mutex);
		bucketGC(ct, b, UINT64_MAX); /* now=UINT64_MAX ensures all-timeout*/
		UNLOCK(&b->mutex);
		MUTEX_DESTROY(&b->mutex);
	}
	free(ct->bucket);
	free(ct);
}
