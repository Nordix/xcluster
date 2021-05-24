#include "itempool.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>

static int chkItemPoolStats(
	struct ItemPool* pool,
	unsigned nFree, unsigned nAllocatedCalls, unsigned nRejected)
{
	struct ItemPoolStats const* stats = itemPoolStats(pool);
	int rc = stats->nFree == nFree
		&& stats->nAllocatedCalls == nAllocatedCalls
		&& stats->nRejected == nRejected;
	itemPoolClearStats(pool);
	return rc;
}

static int nitems = 0;
static void itemInitFn(struct Item* item)
{
	assert(item != NULL);
	nitems++;
	*((int*)item->data) = nitems;
}
static void itemDestroyFn(struct Item* item)
{
	static int cnt = 0;
	assert(item != NULL);
	cnt++;
	assert(*((int*)item->data) == cnt);
	nitems--;
}

int
main(int argc, char* argv[])
{
	// ----------------------------------------------------------------------
	// Generic Item Pool tests

	struct Item* item;
	struct ItemPool* ipool;
	struct ItemPoolStats const* stats;

	ipool = itemPoolCreate(4, 256, itemInitFn);
	assert(ipool != NULL);
	assert(nitems == 4);
	stats = itemPoolStats(ipool);
	assert(stats->size == 4);
	assert(stats->itemSize == 256);
	assert(chkItemPoolStats(ipool, 4, 0, 0));

	itemFree(NULL);
	assert(chkItemPoolStats(ipool, 4, 0, 0));

	item = itemAllocate(ipool);
	assert(item != NULL);
	assert(item->next == NULL);
	assert(chkItemPoolStats(ipool, 3, 1, 0));

	itemFree(item);
	assert(chkItemPoolStats(ipool, 4, 0, 0));

	item = itemAllocateWithNext(ipool, NULL);
	item = itemAllocateWithNext(ipool, item);
	assert(item != NULL);
	assert(item->next != NULL);
	assert(chkItemPoolStats(ipool, 2, 2, 0));

	item = itemAllocateWithNext(ipool, item);
	item = itemAllocateWithNext(ipool, item);
	assert(chkItemPoolStats(ipool, 0, 2, 0));

	assert(itemAllocate(ipool) == NULL);
	assert(itemAllocate(ipool) == NULL);
	assert(chkItemPoolStats(ipool, 0, 2, 2));

	item = itemAllocateWithNext(ipool, item);
	assert(item == NULL);
	assert(chkItemPoolStats(ipool, 4, 1, 1));

	itemPoolDestroy(ipool, itemDestroyFn);
	assert(nitems == 0);

	printf("==== ct-utils-test OK\n");
	return 0;
}

