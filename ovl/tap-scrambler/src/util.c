/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/if_tun.h>
#include <net/if.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <arpa/inet.h>

int tun_alloc(char const* dev, int flags) {

	if (dev == NULL) {
		return -1;
	}

	int fd;
	if((fd = open("/dev/net/tun" , O_RDWR)) < 0) {
		perror("Opening /dev/net/tun");
		return fd;
	}

	struct ifreq ifr;
	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_flags = flags | IFF_TAP;
	strncpy(ifr.ifr_name, dev, IFNAMSIZ);

	if(ioctl(fd, TUNSETIFF, (void*)&ifr) < 0) {
		perror("ioctl(TUNSETIFF)");
		close(fd);
		return -1;
	}

	return fd;
}

int get_mtu(char const* dev)
{
	int fd = socket(PF_INET, SOCK_DGRAM, 0);
	if (fd < 0) {
		perror("socket PF_INET");
		return -1;
	}
	struct ifreq ifr;
	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, dev);
	if (ioctl(fd, SIOCGIFMTU, &ifr) < 0) {
		perror("ioctl SIOCGIFMTU");
		return -1;
	}
	close(fd);
	return ifr.ifr_mtu;
}

uint16_t ether_type(uint8_t const* data)
{
	struct ethhdr const* ethhdr = (struct ethhdr const*)data;
	return ntohs(ethhdr->h_proto);
}

static char const* ipProtoString(uint8_t proto)
{
	static char buf[16];
	switch (proto) {
	case IPPROTO_IP: return "IP/HOPOPTS";
	case IPPROTO_ICMP: return "ICMP";
	case IPPROTO_IGMP: return "IGMP";
	case IPPROTO_IPIP: return "IPIP";
	case IPPROTO_TCP: return "TCP";
	case IPPROTO_EGP: return "EGP";
	case IPPROTO_PUP: return "PUP";
	case IPPROTO_UDP: return "UDP";
	case IPPROTO_IDP: return "IDP";
	case IPPROTO_TP: return "TP";
	case IPPROTO_DCCP: return "DCCP";
	case IPPROTO_IPV6: return "IPV6";
	case IPPROTO_RSVP: return "RSVP";
	case IPPROTO_GRE: return "GRE";
	case IPPROTO_ESP: return "ESP";
	case IPPROTO_AH: return "AH";
	case IPPROTO_MTP: return "MTP";
	case IPPROTO_BEETPH: return "BEETPH";
	case IPPROTO_ENCAP: return "ENCAP";
	case IPPROTO_PIM: return "PIM";
	case IPPROTO_COMP: return "COMP";
	case IPPROTO_SCTP: return "SCTP";
	case IPPROTO_UDPLITE: return "UDPLITE";
	case IPPROTO_MPLS: return "MPLS";
	case IPPROTO_RAW: return "RAW";
	case IPPROTO_ROUTING: return "ROUTING";
	case IPPROTO_FRAGMENT: return "FRAGMENT";
	case IPPROTO_ICMPV6: return "ICMPV6";
	case IPPROTO_NONE: return "NONE";
	case IPPROTO_DSTOPTS: return "DSTOPTS";
	case IPPROTO_MH: return "MH";
	default:;
	}
	sprintf(buf, "%u", proto);
	return buf;
}

static void printIpHeader(uint8_t const* data)
{
	struct iphdr const* iph = (struct iphdr const*)data;
	char src[24], dst[24];

	uint16_t frag = ntohs(iph->frag_off);
	if (frag & (IP_MF | IP_OFFMASK)) {
		printf(
			"  IPv4: %s -> %s, %s, frag %u/%u, %s\n",
			inet_ntop(AF_INET, &iph->saddr, src, sizeof(src)),
			inet_ntop(AF_INET, &iph->daddr, dst, sizeof(dst)),
			ipProtoString(iph->protocol),
			frag & IP_OFFMASK, ntohs(iph->id),
			frag & IP_MF ? "MF":"last-frag");
	} else {
		printf(
			"  IPv4: %s -> %s, %s %s\n",
			inet_ntop(AF_INET, &iph->saddr, src, sizeof(src)),
			inet_ntop(AF_INET, &iph->daddr, dst, sizeof(dst)),
			ipProtoString(iph->protocol),
			frag & IP_DF ? "DF":"");
	}
	//void const* nxthdr = ((uint32_t*)data + iph->ihl);
}

static void printIp6Header(uint8_t const* data)
{
	struct ip6_hdr const* iph = (struct ip6_hdr const*)data;
	char src[48], dst[48];

	printf(
		"  IPv6: %s -> %s, nxt %s\n",
		inet_ntop(AF_INET6, &iph->ip6_src, src, sizeof(src)),
		inet_ntop(AF_INET6, &iph->ip6_dst, dst, sizeof(dst)),
		ipProtoString(iph->ip6_nxt));
	if (iph->ip6_nxt == IPPROTO_FRAGMENT) {
		struct ip6_frag const* fhdr = (struct ip6_frag const*)(data + 40);
		uint16_t frag = ntohs(fhdr->ip6f_offlg);
		printf(
			"        %u/%u %s, nxt %s\n",
			frag >> 3, ntohl(fhdr->ip6f_ident), frag & 1 ? "MF":"last-frag",
			ipProtoString(fhdr->ip6f_nxt));
	}
}

void printPacket(uint8_t const* data, unsigned len)
{
	struct ethhdr const* ethhdr = (struct ethhdr const*)data;
	char src[24], dst[24];
	printf(
		"Packet %u: %s -> %s, 0x%04x\n",
		len, ether_ntoa_r((const struct ether_addr*)ethhdr->h_source, src),
		ether_ntoa_r((const struct ether_addr*)ethhdr->h_dest, dst),
		ntohs(ethhdr->h_proto));
	switch (ntohs(ethhdr->h_proto)) {
	case ETH_P_IP:
		printIpHeader(data + ETH_HLEN);
		break;
	case ETH_P_IPV6:
		printIp6Header(data + ETH_HLEN);
		break;
	default:;
	}
}
