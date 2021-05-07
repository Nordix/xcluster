/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>

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

unsigned ipv4TcpUdpHash(void const* data, unsigned len)
{
	// We hash on addresses and ports
	struct iphdr* hdr = (struct iphdr*)data;
	int32_t hashData[3];
	hashData[0] = hdr->saddr;
	hashData[1] = hdr->daddr;
	hashData[2] = *((uint32_t*)data + hdr->ihl);
	return djb2_hash((uint8_t const*)hashData, sizeof(hashData));
}
unsigned ipv4IcmpHash(void const* data, unsigned len)
{
	struct iphdr* hdr = (struct iphdr*)data;
	struct icmphdr* ihdr = (struct icmphdr*)((uint32_t*)data + hdr->ihl);
	int32_t hashData[3];
	hashData[0] = hdr->saddr;
	hashData[1] = hdr->daddr;
	switch (ihdr->type) {
	case ICMP_ECHO:
		// We hash on addresses and id
		hashData[2] = ihdr->un.echo.id;
		break;
	case ICMP_FRAG_NEEDED:
		// This is a PMTU discovery reply. We must use the *inner*
		// header to make sure the origial sender gets the reply.
	default:
		hashData[2] = 0;
	}
	return djb2_hash((uint8_t const*)hashData, sizeof(hashData));
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

	return ipv4TcpUdpHash(pkt, len);
}
