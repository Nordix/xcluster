/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <arpa/inet.h>
#include <netinet/ip.h>

char const* protocolString(unsigned p)
{
	static char buf[8];
	switch (p) {
	case IPPROTO_ICMP: return "ICMP";
	case IPPROTO_TCP: return "TCP";
	case IPPROTO_UDP: return "UDP";
	case IPPROTO_ICMPV6: return "ICMPV6";
	default:
		sprintf(buf, "%u", p);
	}
	return buf;
}

void ipv4Print(unsigned len, uint8_t const* pkt)
{
	struct iphdr* hdr = (struct iphdr*)pkt;
	char src[16], dst[16];
	char const* frag = "";
	if (ntohs(hdr->frag_off) & (IP_OFFMASK|IP_MF))
		frag = "frag";
	printf(
		"  IPv4: %s -> %s, %s %s\n",
		inet_ntop(AF_INET, &hdr->saddr, src, sizeof(src)),
		inet_ntop(AF_INET, &hdr->daddr, dst, sizeof(dst)),
		protocolString(hdr->protocol), frag);
}

unsigned ipv4Hash(unsigned len, uint8_t const* pkt)
{
	struct iphdr* hdr = (struct iphdr*)pkt;

	// We can't handle any fragments yet.
	if (ntohs(hdr->frag_off) & (IP_OFFMASK|IP_MF))
		return 0;

	// We only handle TCP and UDP
	if (hdr->protocol != IPPROTO_TCP && hdr->protocol != IPPROTO_UDP)
		return 0;

	// We hash on addresses and ports
	uint32_t hashData[3];
	hashData[0] = hdr->saddr;
	hashData[1] = hdr->saddr;
	hashData[2] = *((uint32_t*)pkt + hdr->ihl);

	return djb2_hash((uint8_t const*)hashData, sizeof(hashData));
}
