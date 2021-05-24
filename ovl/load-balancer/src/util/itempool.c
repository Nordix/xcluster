/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

/*
   Generic Item Pool.
   Simple thread-safe item pool for a limited number of items.
 */

#include "itempool.h"
#include <pthread.h>
#include <stdlib.h>
#include <stdint.h>

#define MUTEX(x) pthread_mutex_t x
#define LOCK(x) pthread_mutex_lock(x)
#define UNLOCK(x) pthread_mutex_unlock(x)
#define MUTEX_DESTROY(x) pthread_mutex_destroy(x)
#define MUTEX_INIT(x) pthread_mutex_init(x, NULL);
#define STATS(x) x

struct ItemPool {
	MUTEX(mutex);
	struct ItemPoolStats stats;
	struct Item* free;
	void* mem;
};

static void itemPoolInit(
	struct ItemPool* pool, unsigned maxItems, unsigned itemSize,
	itemFn_t itemInitFn)
{
	MUTEX_INIT(&pool->mutex);
	pool->stats.size = maxItems;
	pool->stats.itemSize = itemSize;
	pool->stats.nAllocatedCalls = 0;
	pool->stats.nRejected = 0;
	pool->free = NULL;
	pool->stats.nFree = 0;

	if (maxItems == 0) {
		return;
	}

	unsigned realItemSize = sizeof(struct Item) + itemSize;
	pool->mem = malloc(maxItems * realItemSize);
	if (pool->mem == NULL) {
		return;
	}
	pool->stats.nFree = maxItems;

	struct Item* item = pool->mem;
	for (unsigned i = 0; i < maxItems; i++) {
		item->next = pool->free;
		pool->free = item;
		item->pool = pool;
		item->len = itemSize;
		if (itemInitFn != NULL)
			itemInitFn(item);
		item = (struct Item*)((uint8_t*)item + realItemSize);
	}
}

struct ItemPool* itemPoolCreate(
	unsigned maxItems, unsigned itemSize, itemFn_t itemInitFn)
{
	struct ItemPool* p = malloc(sizeof(*p));
	if (p == NULL)
		return NULL;
	itemPoolInit(p, maxItems, itemSize, itemInitFn);
	return p;
}

void itemPoolDestroy(struct ItemPool* pool, itemFn_t itemDestroyFn)
{
	if (itemDestroyFn != NULL) {
		unsigned realItemSize = sizeof(struct Item) + pool->stats.itemSize;
		struct Item* item = pool->mem;
		for (unsigned i = 0; i < pool->stats.size; i++) {
			itemDestroyFn(item);
			item = (struct Item*)((uint8_t*)item + realItemSize);
		}
	}
	MUTEX_DESTROY(&pool->mutex);
	free(pool->mem);
	free(pool);
}

struct ItemPoolStats const* itemPoolStats(struct ItemPool* pool)
{
	return &pool->stats;
}

void itemPoolClearStats(struct ItemPool* pool)
{
	LOCK(&pool->mutex);
	pool->stats.nAllocatedCalls = 0;
	pool->stats.nRejected = 0;
	UNLOCK(&pool->mutex);
}


struct Item* itemAllocate(struct ItemPool* pool)
{
	LOCK(&pool->mutex);
	STATS(pool->stats.nAllocatedCalls++);
	struct Item* f = pool->free;
	if (f != NULL) {
		pool->free = f->next;
		f->next = NULL;
		STATS(pool->stats.nFree--);
	} else {
		STATS(pool->stats.nRejected++);
	}
	UNLOCK(&pool->mutex);
	return f;
}

void itemFree(struct Item* items)
{
	if (items == NULL)
		return;
	struct ItemPool* pool = items->pool;
	LOCK(&pool->mutex);
	while (items != NULL) {
		struct Item* f = items;
		items = items->next;
		f->next = pool->free;
		pool->free = f;
		STATS(pool->stats.nFree++);
	}
	UNLOCK(&pool->mutex);
}

struct Item* itemAllocateWithNext(
	struct ItemPool* pool, struct Item* next)
{
	struct Item* item = itemAllocate(pool);
	if (item != NULL)
		item->next = next;
	else
		itemFree(next);
	return item;
}

