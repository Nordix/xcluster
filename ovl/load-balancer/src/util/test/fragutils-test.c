#include "fragutils.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#define MS 1000000				/* One milli second in nanos */

#define xstr(a) str(a)
#define str(a) #a
#define S_CMP(x) if (a->x != b->x) { rc = 1; \
		printf("a.%s = %u; != %u\n", xstr(x), b->x, a->x); }

static int statsCmp(struct fragStats* a, struct fragStats* b)
{
	int rc = 0;
	S_CMP(ttlMillis);
	S_CMP(size);
	S_CMP(active);
	S_CMP(collisions);
	S_CMP(inserts);
	S_CMP(rejectedInserts);
	S_CMP(lookups);
	S_CMP(objGC);
	S_CMP(maxBuckets);
	S_CMP(maxFragments);
	S_CMP(mtu);
	S_CMP(storedFrags);
	return rc;
}

static int numItems(struct Item* items)
{
	int i = 0;
	while (items != NULL) {
		i++;
		items = items->next;
	}
	return i;
}


int
cmdFragutilsBasic(int argc, char* argv[])
{
	struct timespec now = {0,0};
	struct fragStats a;
	struct fragStats b;
	struct ctKey key = {IN6ADDR_ANY_INIT,IN6ADDR_ANY_INIT,{0ull}};
	int rc;
	unsigned hash;
	struct Item* item;

	// Init and check stats
	fragInit(2, 3, 4, 1500, 100);
	fragGetStats(&now, &a);
	memset(&b, 0, sizeof(b));
	b.ttlMillis = 100;
	b.size = 2;
	b.maxBuckets = 3;
	b.maxFragments = 4;
	b.mtu = 1500;
	assert(statsCmp(&a, &b) == 0);

	// Unsuccesful lookup
	fragGetStats(&now, &a);
	a.lookups++;
	rc = fragGetHash(&now, &key, &hash);
	assert(rc == -1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Insert a first-fragment and look it up
	fragGetStats(&now, &a);
	a.lookups++;
	a.inserts++;
	a.active++;
	rc = fragInsertFirst(&now, &key, 5);
	assert(rc == 0);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	fragGetStats(&now, &a);
	a.lookups++;
	rc = fragGetHash(&now, &key, &hash);
	assert(rc == 0);
	assert(hash == 5);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Step time and check GC
	fragGetStats(&now, &a);
	a.active = 0;
	a.objGC++;
	now.tv_nsec += 150 * MS;
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Add 3 sub-frags
	fragGetStats(&now, &a);
	a.active++;
	a.lookups++;
	a.inserts++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	fragGetStats(&now, &a);
	a.lookups++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	fragGetStats(&now, &a);
	a.lookups++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Step time and check that the (3) fragments are released
	fragGetStats(&now, &a);
	a.active = 0;
	a.objGC++;
	a.storedFrags = 0;
	now.tv_nsec += 150 * MS;
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Add 3 sub-frags #2
	fragGetStats(&now, &a);
	a.active++;
	a.lookups++;
	a.inserts++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	fragGetStats(&now, &a);
	a.lookups++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	fragGetStats(&now, &a);
	a.lookups++;
	a.storedFrags++;
	rc = fragGetHashOrStore(&now, &key, &hash, &key, sizeof(key));
	assert(rc == 1);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);

	// Get and release the stored fragments
	fragGetStats(&now, &a);
	a.lookups++;
	item = fragGetStored(&now, &key);
	assert(item != NULL);
	assert(numItems(item) == 3);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);
	a.storedFrags = 0;
	itemFree(item);
	fragGetStats(&now, &b);
	assert(statsCmp(&a, &b) == 0);
	

	printf("==== fragutils-test OK\n");
	return 0;
}

#ifdef CMD
void addCmd(char const* name, int (*fn)(int argc, char* argv[]));
__attribute__ ((__constructor__)) static void addCommand(void) {
	addCmd("fragutils_basic", cmdFragutilsBasic);
}
#else
int main(int argc, char* argv[])
{
	return cmdFragutilsBasic(argc, argv);
}
#endif
