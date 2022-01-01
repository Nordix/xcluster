/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021-2022 Nordix Foundation
*/

#include "util.h"
#include <die.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <netinet/ether.h>
#include <arpa/inet.h>			/* htons */
#include <unistd.h>
#include <netinet/ip6.h>
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
int macParse(char const* str, uint8_t* mac)
{
	int values[6];
	int i = sscanf(
		str, "%x:%x:%x:%x:%x:%x%*c",
		&values[0], &values[1], &values[2],
		&values[3], &values[4], &values[5]);

	if (i == 6) {
		/* convert to uint8_t */
		for( i = 0; i < 6; ++i )
			mac[i] = (uint8_t) values[i];
		return 0;
	}
    /* invalid mac */
	return -1;
}
void macParseOrDie(char const* str, uint8_t* mac)
{
	if (macParse(str, mac) != 0)
		die("Parse MAC failed [%s]\n", str);
}

char const* macToString(uint8_t const* mac)
{
#define MAX_MACBUF 2
	static char buf[MAX_MACBUF][20];
	static int bindex = 0;
	if (bindex++ == MAX_MACBUF) bindex = 0;
	sprintf(
		buf[bindex], "%02x:%02x:%02x:%02x:%02x:%02x",
		mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
	return buf[bindex];
}


#include <sys/ioctl.h>
#include <net/if.h>	//ifreq

int getMAC(char const* iface, /*out*/ unsigned char* mac)
{
	int fd;
	struct ifreq ifr;
	
	fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (fd < 0) return -1;
	ifr.ifr_addr.sa_family = AF_INET;
	strncpy(ifr.ifr_name , iface , IFNAMSIZ-1);
	if (ioctl(fd, SIOCGIFHWADDR, &ifr) < 0) {
		close(fd);
		return -1;
	}
	close(fd);
	memcpy(mac, ifr.ifr_hwaddr.sa_data, ETH_ALEN);
	return 0;
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

void framePrint(unsigned len, uint8_t const* pkt)
{
	if (len < sizeof(struct ethhdr)) {
		printf("Short packet %u\n", len);
		return;
	}
	struct ethhdr const* eth = (struct ethhdr const*)pkt;
	pkt += sizeof(struct ethhdr);
	len -= sizeof(struct ethhdr);
	uint16_t proto = htons(eth->h_proto);
	printf("%s -> %s; 0x%04x\n", macToString(eth->h_source), macToString(eth->h_dest), proto);
	switch (proto) {
	case ETH_P_IP:
		ipv4Print(len, pkt);
		break;
	case ETH_P_IPV6:
		ipv6Print(len, pkt);
		break;
	default:;
	}
}
