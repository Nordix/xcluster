/*
  SPDX-License-Identifier: MIT License
  Copyright (c) 2021 Nordix Foundation
*/

#include "nfqueue.h"
#include <util.h>
#include <stdlib.h>
#include <stdio.h>
//#include <arpa/inet.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>

#define D(x)
#define Dx(x) x
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
		if (ipv6HandleFragment(payload, plen, &hash) != 0) {
			Dx(printf("IPv6 fragment dropped\n"));
			return -1;
		}
		D({
				struct ctStats const* stat = ipv6FragStats();
				printf("Frag hash=%u, active=%u\n", hash, stat->active);
			});
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
	char const* qnum = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "lb [options]\n"
		 "  Load-balance"},
		{"tshm", &targetShm, 0, "Target shared memory"},
		{"lbshm", &lbShm, 0, "Lb shared memory"},
		{"queue", &qnum, 0, "NF-queue to listen to (default 2)"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	int q = 2;
	if (qnum != NULL)
		q = atoi(qnum);
	st = mapSharedDataOrDie(targetShm,sizeof(*st), O_RDONLY);
	slb = mapSharedDataOrDie(lbShm,sizeof(*slb), O_RDONLY);
	return nfqueueRun(q, packetHandleFn);
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("lb", cmdLb);
}
