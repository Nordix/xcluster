/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/ether.h>

void die(char const* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	exit(EXIT_FAILURE);
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

static int verifyRequiredOptions(
	struct option const* long_options, unsigned required, unsigned got)
{
	got = got & required;
	if (required == got) return 0;
	unsigned i, m;
	for (i = 0; i < 32; i++) {
		m = (1 << i);
		if ((required & m) != (got & m)) {
			char const* opt = "(unknown)";
			struct option const* o;
			for (o = long_options; o->name != NULL; o++) {
				if (o->val == i) {
					opt = o->name;
					break;
				}
			}
			fprintf(stderr, "Missing option [--%s]\n", opt);
		}
	}
	return -1;
}

static void printUsage(struct Option const* options)
{
	struct Option const* o;
	for (o = options; o->name != NULL; o++) {
		if (strcmp(o->name, "help") == 0) {
			puts(o->help);
			break;
		}
	}
	for (o = options; o->name != NULL; o++) {
		if (strcmp(o->name, "help") == 0)
			continue;
		printf(
			"  --%s= %s %s\n",
			o->name, o->help, o->required ? "(required)":"");
	}
}

int parseOptions(int argc, char* argv[], struct Option const* options)
{
	unsigned required = 0;
	int i, len = 0;
	struct Option const* o;
	for (o = options; o->name != NULL; o++)
		len++;
	if (len >= 32)
		die("Too many options %d (max 31)\n", len);
	struct option long_options[len+1];
	memset(long_options, 0, sizeof(long_options));
	for (i = 0; i < len; i++) {
		o = options + i;
		struct option* lo = long_options + i;
		lo->name = o->name;
		lo->has_arg = o->arg == NULL ? no_argument : required_argument;
		lo->val = i;
		if (o->required == REQUIRED)
			required |= (1 << i);
	}

	int option_index = 0;
	unsigned got = 0;
	i = getopt_long_only(argc, argv, "", long_options, &option_index);
	while (i >= 0) {
		if (i >= 32)
			return -1;
		got |= (1 << i);
		o = options + i;
		if (strcmp(o->name, "help") == 0) {
			printUsage(options);
			return 0;
		}
		if (o->arg != NULL)
			*(o->arg) = optarg;
		i = getopt_long_only(argc, argv, "", long_options, &option_index);
	}
	if (verifyRequiredOptions(long_options, required, got) != 0)
		return -1;
	return optind;
}

int parseOptionsOrDie(int argc, char* argv[], struct Option const* options)
{
	int nopt = parseOptions(argc, argv, options);
	if (nopt > 0)
		return nopt;
	exit(nopt == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
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
