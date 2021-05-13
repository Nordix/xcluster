/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <arpa/inet.h>
#include <netinet/ip6.h>
#include <netinet/icmp6.h>
#include <string.h>
#include <stdlib.h>

char const* protocolString(unsigned p);

void ipv6Print(unsigned len, uint8_t const* pkt)
{
	struct ip6_hdr* hdr = (struct ip6_hdr*)pkt;
	char src[42], dst[42];
	char const* frag = "";
	printf(
		"  IPv6: %s -> %s, %s %s\n",
		inet_ntop(AF_INET6, &hdr->ip6_src, src, sizeof(src)),
		inet_ntop(AF_INET6, &hdr->ip6_dst, dst, sizeof(dst)),
		protocolString(hdr->ip6_nxt), frag);
}

static unsigned
ipv6TcpUdpHash(struct ip6_hdr const* h, uint32_t const* ports)
{
	int32_t hashData[9];
	memcpy(hashData, &h->ip6_src, 32);
	hashData[8] = *ports;
	return djb2_hash((uint8_t const*)hashData, sizeof(hashData));
}
static unsigned
ipv6IcmpHash(struct ip6_hdr const* h, struct icmp6_hdr const* ih)
{
	int32_t hashData[9];
	memcpy(hashData, &h->ip6_src, 32);
	hashData[8] = ih->icmp6_id;
	return djb2_hash((uint8_t const*)hashData, sizeof(hashData));
}

unsigned ipv6Hash(void const* data, unsigned len)
{
	struct ip6_hdr* hdr = (struct ip6_hdr*)data;
	unsigned hash = 0;
	switch (hdr->ip6_nxt) {
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		hash = ipv6TcpUdpHash(hdr, data + 40);
		break;
	case IPPROTO_ICMPV6:
		hash = ipv6IcmpHash(hdr, data + 40);
		break;
	case IPPROTO_SCTP:
	default:;
	}
	return hash;
}
unsigned ipv6AddressHash(void const* data, unsigned len)
{
	struct ip6_hdr const* hdr = data;
	return djb2_hash((uint8_t const*)&hdr->ip6_src, 32);
}

/* ----------------------------------------------------------------------
   Fragmentation handling
 */

#include <time.h>
#define MS 1000000				/* One milli second in nanos */
#define PAFTER(x) (void*)x + (sizeof(*x))
static struct ct* ct = NULL;

#define REFINC(x) __atomic_add_fetch(&(x),1,__ATOMIC_SEQ_CST)
#define REFDEC(x) __atomic_sub_fetch(&(x),1,__ATOMIC_SEQ_CST)

struct FragData {
	int referenceCounter;
	int firstFragmentSeen;
	unsigned hash;
};
static unsigned allocatedFrags = 0;
static unsigned storedPackets = 0;

static void lockFragData(void* data)
{
	struct FragData* f = data;
	REFINC(f->referenceCounter);
}
static void unlockFragData(void* data)
{
	struct FragData* f = data;
	if (REFDEC(f->referenceCounter) <= 0) {
		__atomic_sub_fetch(&allocatedFrags,1,__ATOMIC_RELAXED);
		free(data);
	}
}
static void* allocBucket(void)
{
	return malloc(sizeof_bucket);
}

static void ctInit(void)
{
	if (ct != NULL)
		return;
	ct = ctCreate(
		1024, 250 * MS, unlockFragData, lockFragData, allocBucket, free);
}

static void* lookupOrCreate(struct timespec* now, struct ctKey const* key)
{
	struct FragData* f = ctLookup(ct, now, key);
	if (f == NULL) {
		f = calloc(1, sizeof(*f));
		if (f == NULL)
			return NULL;
		f->referenceCounter = 2; /* ct and our selves = 2 references */
		int rc = ctInsert(ct, now, key, f);
		if (rc == 0) {
			__atomic_add_fetch(&allocatedFrags,1,__ATOMIC_RELAXED);
		} else if (rc < 0) {
			free(f);
			return NULL;
		} else if (rc == 1) {
			// Item already inserted
			free(f);
			f = ctLookup(ct, now, key);
			if (f == NULL)
				return NULL;	/* Some other thread has deleted the
								 * entry. Give up! (should not happen) */
		}
	}
	return f;
}

int ipv6HandleFragment(void const* data, unsigned len, unsigned* hash)
{
	// Prepare
	ctInit();
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);

	// Construct the key lookup and insert if needed
	struct ctKey key;
	struct ip6_hdr* hdr = (struct ip6_hdr*)data;
	struct ip6_frag* fh = (struct ip6_frag*)(data + 40);
	key.dst = hdr->ip6_dst;
	key.src = hdr->ip6_src;
	key.id = fh->ip6f_ident;
	struct FragData* f = lookupOrCreate(&now, &key);
	if (f == NULL) {
		return -1;
	}

	// Check offset
	uint16_t fragOffset = (fh->ip6f_offlg & IP6F_OFF_MASK) >> 3;
	if (fragOffset == 0) {
		// First fragment
		if (f->firstFragmentSeen) {
			// Duplicate
			unlockFragData(f);
			return -1;
		}
		f->firstFragmentSeen = 1;

		// First fragment contains the protocol header.
		switch (fh->ip6f_nxt) {
		case IPPROTO_TCP:		/* (should not happen?) */
		case IPPROTO_UDP:
			f->hash = ipv6TcpUdpHash(hdr, PAFTER(fh));
			break;
		case IPPROTO_ICMPV6:
			f->hash = ipv6IcmpHash(hdr, PAFTER(fh));
			break;
		case IPPROTO_SCTP:
		default:
			f->hash = 0;
		}
		*hash = f->hash;

		/*
		  TODO; If there are any subsequent fragments strored re-inject them.
		 */

		unlockFragData(f);
		return 0;
	}

	// NOT First fragment.
	if (f->firstFragmentSeen) {
		// We have seen the first fragment and the hash is valid
		*hash = f->hash;
		unlockFragData(f);
		return 0;
	}

	/*
	  This is the hard case. We have got an out-of-order fragment
	  before the first fragment. We must store the packet and inject
	  it later when the first fragment has arrived.
	 */
	unlockFragData(f);
	return -1;					/* NYI */
}

struct fragStats const* ipv6FragStats(void)
{
	static struct fragStats stats = {0};
	ctInit();
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	struct ctStats const* ctstats = ctStats(ct, &now);
	stats.active = ctstats->active;
	stats.collisions = ctstats->collisions;
	stats.inserts = ctstats->inserts;
	stats.rejectedInserts = ctstats->rejectedInserts;
	stats.lookups = ctstats->lookups;
	stats.allocatedFrags = allocatedFrags;
	stats.storedPackets = storedPackets;
	return &stats;
}
