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

#define HASH(d,l) djb2_hash(d,l)

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
	return HASH((uint8_t const*)hashData, sizeof(hashData));
}
static unsigned
ipv6IcmpHash(struct ip6_hdr const* h, struct icmp6_hdr const* ih)
{
	int32_t hashData[9];
	memcpy(hashData, &h->ip6_src, 32);
	hashData[8] = ih->icmp6_id;
	return HASH((uint8_t const*)hashData, sizeof(hashData));
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
	return HASH((uint8_t const*)&hdr->ip6_src, 32);
}

/* ----------------------------------------------------------------------
   Fragmentation handling
 */

#include "fragutils.h"
#include <time.h>
#include <pthread.h>

#define PAFTER(x) (void*)x + (sizeof(*x))

int ipv6HandleFragment(void const* data, unsigned len, unsigned* hash)
{
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);

	// Construct the key
	struct ctKey key;
	struct ip6_hdr* hdr = (struct ip6_hdr*)data;
	struct ip6_frag* fh = (struct ip6_frag*)(data + 40);
	key.dst = hdr->ip6_dst;
	key.src = hdr->ip6_src;
	key.id = fh->ip6f_ident;

	// Check offset to see if this is the first fragment
	uint16_t fragOffset = (fh->ip6f_offlg & IP6F_OFF_MASK) >> 3;
	if (fragOffset == 0) {
		// First fragment. contains the protocol header.
		switch (fh->ip6f_nxt) {
		case IPPROTO_TCP:		/* (should not happen?) */
		case IPPROTO_UDP:
			*hash = ipv6TcpUdpHash(hdr, PAFTER(fh));
			break;
		case IPPROTO_ICMPV6:
			*hash = ipv6IcmpHash(hdr, PAFTER(fh));
			break;
		case IPPROTO_SCTP:
		default:
			*hash = 0;
		}
		if (fragInsertFirst(&now, &key, *hash) != 0) {
			return -1;
		}

		/* Check if we have any stored fragments that should be
		 * re-injected */
		struct Item* storedFragments = fragGetStored(&now, &key);
		if (storedFragments != NULL) {
			unsigned cnt = 0;
			for (struct Item* i = storedFragments; i != NULL; i = i->next)
				cnt++;
			printf("Dropped %u stored fragments\n", cnt);
			itemFree(storedFragments);
			return -1;	/* NYI */
		}
		return 0;				/* First fragment handled. Hash stored. */
	}

	/*
	  Not the first fragment. Get the hash if possible or store this
	  fragment if not.
	*/

	return fragGetHashOrStore(&now, &key, hash, data, len);
}
