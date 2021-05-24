/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

/*
   Generic Item Pool.
   Simple thread-safe item pool for a limited number of items.

   It is the user's responsibility to make sure that the stored data
   does not exceed the itemSize, and that no items are in use when
   itemPoolDestroy() is called.
*/

struct ItemPool;
struct Item {
	struct ItemPool* pool;		/* NO NOT TOUCH! */
	unsigned len;				/* Only used by the caller */
	struct Item* next;			/* May be used by the caller */
	unsigned char data[0];		/* (really itemSize bytes of data) */
};

struct ItemPoolStats {
	unsigned size;
	unsigned itemSize;
	unsigned nFree;
	unsigned nAllocatedCalls;	/* Number of itemAllocate calls */
	unsigned nRejected;			/* Number of itemAllocate calls rejected */
};

/*
  Similar to container_of() but for an Item. If you only have the
  "data[0]" pointer "p", e.g. passed from a user, get the Item with;
  struct Item* item = ITEM_OF(p);
*/
#define ITEM_OF(p) (struct Item*)(p - offsetof(struct Item, data))

/*
  If passed a itemFn_t function is called for every item on
  itemPoolCreate() and itemPoolDestroy(). This let the caller
  manupulate data if needed. An example may be to init/destoy
  mutex'es.
*/
typedef void (*itemFn_t)(struct Item* item);

struct ItemPool* itemPoolCreate(
	unsigned maxItems, unsigned itemSize, itemFn_t itemInitFn);
void itemPoolDestroy(struct ItemPool* pool, itemFn_t itemDestroyFn);
struct ItemPoolStats const* itemPoolStats(struct ItemPool* pool);
void itemPoolClearStats(struct ItemPool* pool);
struct Item* itemAllocate(struct ItemPool* pool);
void itemFree(struct Item* items);
struct Item* itemAllocateWithNext(struct ItemPool* pool, struct Item* next);
