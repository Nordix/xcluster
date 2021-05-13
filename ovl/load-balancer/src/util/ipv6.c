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

static void* allocBucket(void)
{
	return malloc(sizeof_bucket);
}

static void ctInit(void)
{
	if (ct != NULL)
		return;
	ct = ctCreate(1024, 250 * MS, free, NULL, allocBucket, free);
}

struct FragData {
	unsigned hash;
};

int ipv6HandleFragment(void const* data, unsigned len, unsigned* hash)
{
	// Prepare
	ctInit();
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);

	// Construct the key and lookup
	struct ctKey key;
	struct ip6_hdr* hdr = (struct ip6_hdr*)data;
	struct ip6_frag* fh = (struct ip6_frag*)(data + 40);
	key.dst = hdr->ip6_dst;
	key.src = hdr->ip6_src;
	key.id = fh->ip6f_ident;
	struct FragData* f = ctLookup(ct, &now, &key);

	// Check offset
	uint16_t fragOffset = (fh->ip6f_offlg & IP6F_OFF_MASK) >> 3;
	if (fragOffset == 0) {
		// First fragment
		if (f != NULL) {
			// Should always be NULL unless we have a duplicate
			return -1;
		}
		f = malloc(sizeof(*f));
		if (f == NULL)
			return -1;
		// First fragment. Contains the protocol header.
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
		if (ctInsert(ct, &now, &key, f) != 0)
			return -1;
		*hash = f->hash;
		return 0;
	}

	// NOT First fragment. We should have a connection entry
	if (f == NULL)
		return -1;				/* Nope */
	*hash = f->hash;
	if ((fh->ip6f_offlg & IP6F_MORE_FRAG) == 0) {
		// Last fragment
		ctRemove(ct, &now, &key);
	}
	return 0;
}
struct ctStats const* ipv6FragStats(void)
{
	ctInit();
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	return ctStats(ct, &now);
}
