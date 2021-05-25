/*
  SPDX-License-Identifier: MIT License
  Copyright (c) 2021 Nordix Foundation
*/

#include "nfqueue.h"
#include <fragutils.h>
#include <util.h>
#include <stdlib.h>
#include <stdio.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <time.h>

#if 0
#define D(x)
#define Dx(x) x
static void printFragStats(struct timespec* now)
{
	struct fragStats stats;
	fragGetStats(now, &stats);
	printf(
		"Frag Stats;\n"
		"  active=%u, collisions=%u, inserts=%u(%u), lookups=%u, gc=%u\n"
		"  storedFrags=%u\n",
		stats.active, stats.collisions, stats.inserts,
		stats.rejectedInserts, stats.lookups, stats.objGC,
		stats.storedFrags); 
}
static void printIpv6FragStats(void)
{
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);

	static struct limiter* l = NULL;
	if (l == NULL)
		l = limiterCreate(100, 1100);
	if (limiterGo(&now, l))
		printFragStats(&now);
}
#else
#define D(x)
#define Dx(x)
#endif

#define HASH djb2_hash

static struct SharedData* st;
static struct SharedData* slb;


static int handleIpv4(void* payload, unsigned plen)
{
	struct iphdr* hdr = (struct iphdr*)payload;

	if (ntohs(hdr->frag_off) & (IP_OFFMASK|IP_MF)) {
		Dx(printf("IPv4 fragment dropped\n"));
		return -1;
	}

	unsigned hash = 0;
	switch (hdr->protocol) {
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		hash = ipv4TcpUdpHash(payload, plen);
		break;
	case IPPROTO_ICMP:
		hash = ipv4IcmpHash(payload, plen);
		break;
	case IPPROTO_SCTP:
	default:;
	}
	return st->magd.lookup[hash % st->magd.M] + st->fwOffset;
}

static int handleIpv6(void* payload, unsigned plen)
{
	unsigned hash;

	struct ip6_hdr* hdr = (struct ip6_hdr*)payload;
	if (hdr->ip6_nxt == IPPROTO_FRAGMENT) {

		// Make an addres-hash and check if we shall forward to the LB tier
		hash = ipv6AddressHash(payload, plen);
		int fw = slb->magd.lookup[hash % slb->magd.M];
		if (fw >= 0 && fw != slb->ownFwmark) {
			Dx(printf("Fragment to LB tier. fw=%d\n", fw));
			return fw + slb->fwOffset; /* To the LB tier */
		}

		// We shall handle the frament here
		int rc = ipv6HandleFragment(payload, plen, &hash);
		if (rc != 0) {
			Dx(printf("IPv6 fragment dropped or stored, rc=%d\n", rc));
			Dx(printIpv6FragStats());
			return -1;
		}
		Dx(printf(
			   "Handle frag locally hash=%u, fwmark=%u\n",
			   hash, st->magd.lookup[hash % st->magd.M] + st->fwOffset));
		Dx(printIpv6FragStats());
	} else {
		hash = ipv6Hash(payload, plen);
	}
	return st->magd.lookup[hash % st->magd.M] + st->fwOffset;
}

static int packetHandleFn(
	unsigned short proto, void* payload, unsigned plen)
{
	int fw = st->fwOffset;
	switch (proto) {
	case ETH_P_IP:
		fw = handleIpv4(payload, plen);
		break;
	case ETH_P_IPV6:
		fw = handleIpv6(payload, plen);
		break;
	default:;
		// We should not get here because ip(6)tables handles only ip (4/6)
		Dx(printf("Unexpected protocol 0x%04x\n", proto));
		fw = -1;
	}
	Dx(printf("Packet; len=%u, fw=%d\n", plen, fw));
	return fw;
}

static int cmdLb(int argc, char **argv)
{
	char const* targetShm = defaultTargetShm;
	char const* lbShm = defaultLbShm;
	char const* ftShm = "ftshm";
	char const* qnum = "2";
	char const* ft_size = "997";
	char const* ft_buckets = "100";
	char const* ft_frag = "100";
	char const* ft_ttl = "200";
	struct Option options[] = {
		{"help", NULL, 0,
		 "lb [options]\n"
		 "  Load-balance"},
		{"tshm", &targetShm, 0, "Target shared memory"},
		{"lbshm", &lbShm, 0, "Lb shared memory"},
		{"queue", &qnum, 0, "NF-queue to listen to (default 2)"},
		{"ft_shm", &ftShm, 0, "Frag table; shared memory stats"},
		{"ft_size", &ft_size, 0, "Frag table; size"},
		{"ft_buckets", &ft_buckets, 0, "Frag table; extra buckets"},
		{"ft_frag", &ft_frag, 0, "Frag table; stored frags"},
		{"ft_ttl", &ft_ttl, 0, "Frag table; ttl"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	st = mapSharedDataOrDie(targetShm,sizeof(*st), O_RDONLY);
	slb = mapSharedDataOrDie(lbShm,sizeof(*slb), O_RDONLY);
	struct ctStats* sft = calloc(1, sizeof(*sft));
	createSharedDataOrDie(ftShm, sft, sizeof(*sft));
	free(sft);
	sft = mapSharedDataOrDie(ftShm, sizeof(*sft), O_RDWR);
	fragInit(
		atoi(ft_size),		/* table size */
		atoi(ft_buckets),	/* Extra buckets for hash collisions */
		atoi(ft_frag),		/* Max stored fragments */
		1550,				/* MTU + some extras */
		atoi(ft_ttl));		/* Fragment TTL in milli seconds */
	fragUseStats(sft);
	printf(
		"FragTable; size=%d, buckets=%d, frag=%d, mtu=%d, ttl=%d\n",
		atoi(ft_size),atoi(ft_buckets),atoi(ft_frag),1550,atoi(ft_ttl));
	return nfqueueRun(atoi(qnum), packetHandleFn);
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("lb", cmdLb);
}
