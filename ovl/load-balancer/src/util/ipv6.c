/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <arpa/inet.h>
#include <netinet/ip6.h>

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
