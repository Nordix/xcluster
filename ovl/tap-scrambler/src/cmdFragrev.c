/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>
#include <string.h>
#include <linux/if_tun.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>

#define D(x)

static char const* const helpText =
	"\nSyntax: fragrev --tap=dev\n"
	"\n"
	"Fragments for incoming fragmented packets are reversed.\n"
	"That means that for TCP/UDP the first fragment containing the\n"
	"ports will end up last.\n";

static int fragCheck(int fd, uint8_t const* data, unsigned len);
static void fragPoolInit(unsigned size, unsigned maxLen);

static int cmdFragrev(int argc, char* argv[])
{
	static struct option const long_options[] = {
		{"help",   no_argument,       0,  1 },
		{"tap",    required_argument, 0,  2 },
		{0,        0,                 0,  0 }
	};
	char const* dev;
	int fd = -1;
	int option_index = 0;
	int c = getopt_long_only(argc, argv, "", long_options, &option_index);
	while (c >= 0) {
		switch (c) {
		case 1:
			fputs(helpText, stdout);
			return EXIT_SUCCESS;
		case 2:
			dev = optarg;
			fd = tun_alloc(dev, IFF_NO_PI);
			break;
		default:
			return EXIT_FAILURE;
		}
		c = getopt_long_only(argc, argv, "", long_options, &option_index);
	}
	if (fd < 0) {
		fprintf(stderr, "Failed to create tap (or none specified)\n");
		return EXIT_FAILURE;
	}

	int mtu = get_mtu(dev);
	if (mtu < 0)
		return EXIT_FAILURE;
	printf("Using MTU %d\n", mtu);
	fragPoolInit(1000, mtu + 100);

	uint8_t buffer[mtu + 100];
	for (;;) {
		int cnt = read(fd, buffer, sizeof(buffer));
		if (cnt < 0)
			return EXIT_FAILURE;

		if (fragCheck(fd, buffer, cnt) == 0)
			continue;			/* Fragment consumed */

		if (write(fd, buffer, cnt) != cnt)
			return EXIT_FAILURE;

	}
	
	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCmdFwd(void) {
	addCmd("fragrev", cmdFragrev);
}

struct FragPacket {
	struct FragPacket* next;
	struct FragPacketPool* pool;
	uint8_t* data;
	unsigned len;
};
struct FragPacketPool {
	unsigned size;
	unsigned allocated;
	unsigned maxLen;
	struct FragPacket* items;
};
static struct FragPacketPool fragPool;

static void fragPoolInit(unsigned size, unsigned maxLen)
{
	/* If we run out of frag buffers we can't reverse all fragments
	 * but traffic will still work. We don't crash or discard packets
	 * or anything. */

	fragPool.size = size;
	fragPool.allocated = 0;
	fragPool.maxLen = maxLen;

	struct FragPacket* frag = malloc(sizeof(*frag) * size);
	fragPool.items = frag;
	uint8_t* data = malloc(maxLen * size);
	while (size-- > 1) {
		frag->pool = &fragPool;
		frag->next = frag + 1;
		frag->data = data;
		frag++;
		data += maxLen;
	}
	frag->pool = &fragPool;
	frag->data = data;
	frag->next = NULL;
}

static struct FragPacket* fragAlloc(uint8_t const* data, unsigned len)
{
	if (fragPool.items == NULL) {
		assert(fragPool.allocated == fragPool.size);
		return NULL;
	}
	struct FragPacket* frag = fragPool.items;
	fragPool.items = frag->next;
	fragPool.allocated++;
	frag->len = len;
	memcpy(frag->data, data, len);
	return frag;
}

static void fragFree(struct FragPacket* frag)
{
	frag->next = frag->pool->items;
	frag->pool->items = frag;
	frag->pool->allocated--;
}

static struct FragPacket* fragQueue = NULL;
static void fragStore(struct FragPacket* frag)
{
	frag->next = fragQueue;
	fragQueue = frag;
}

static void fragSendStored(int fd, uint8_t const* data)
{
	struct FragPacket* frag;
	while (fragQueue != NULL) {
		frag = fragQueue;
		fragQueue = fragQueue->next;
		if (write(fd, frag->data, frag->len) != frag->len)
			exit(EXIT_FAILURE);
		D(printf("Sent strored frag, len=%u\n", frag->len));
		fragFree(frag);
	}
}

static int fragCheck(int fd, uint8_t const* data, unsigned len)
{
	struct ethhdr const* ethhdr = (struct ethhdr const*)data;
	uint16_t frag;

	switch (ntohs(ethhdr->h_proto)) {
	case ETH_P_IP: {
		struct iphdr const* iph = (struct iphdr const*)(data + ETH_HLEN);
		frag = ntohs(iph->frag_off);
		if ((frag & (IP_MF | IP_OFFMASK)) == 0)
			return len;			/* Not fragment */
		if (frag & IP_MF) {
			struct FragPacket* f = fragAlloc(data, len);
			if (f == 0)
				return len;		/* Could not store fragment */
			fragStore(f);
			D(printf("Frag stored, len=%u\n", len));
			return 0;			/* Frag stored */
		} else {
			/* Last fragment, send it */
			if (write(fd, data, len) != len)
				exit(EXIT_FAILURE);
			D(printf("Last frag sent, len=%u\n", len));
			fragSendStored(fd, data);
			return 0;
		}
		break;
	}
	case ETH_P_IPV6: {
		struct ip6_hdr const* iph = (struct ip6_hdr const*)(data + ETH_HLEN);
		if (iph->ip6_nxt != IPPROTO_FRAGMENT)
			return len;			/* Not fragment */
		struct ip6_frag const* fhdr = (struct ip6_frag const*)(data + ETH_HLEN + 40);
		frag = ntohs(fhdr->ip6f_offlg);
		if (frag & 1) {
			struct FragPacket* f = fragAlloc(data, len);
			if (f == 0)
				return len;		/* Could not store fragment */
			fragStore(f);
			D(printf("Frag stored, len=%u\n", len));
			return 0;			/* Frag stored */
		} else {
			/* Last fragment, send it */
			if (write(fd, data, len) != len)
				exit(EXIT_FAILURE);
			D(printf("Last frag sent, len=%u\n", len));
			fragSendStored(fd, data);
			return 0;
		}
		break;
	}
	default:
		return len;				/* Not IP */
	}
}
