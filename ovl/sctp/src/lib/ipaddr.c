/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include "ipaddr.h"
#include <log.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>

int parseAddress(char const* str, int port, struct sockaddr_in6* a)
{
	struct addrinfo hints = {0};
	struct addrinfo* res;
	hints.ai_flags = AI_NUMERICHOST | AI_V4MAPPED;
	hints.ai_family = AF_INET6;
	int rc = getaddrinfo(str, NULL, &hints, &res);
	if (rc != 0) {
		warning("%s [%s]\n", gai_strerror(rc), str);
		return rc;
	}

	debug("Family %d, len %d\n", res->ai_family, res->ai_addrlen);
	memcpy(a, res->ai_addr, res->ai_addrlen);
	freeaddrinfo(res);
	return 0;
}

int parseAddrs(char const* str, int port, struct sockaddr** addrs)
{
	int slen = strlen(str);
	char tmp[slen+1];

	// Get the array length
	int len = 0;
	char* addr;
	strcpy(tmp, str);
	for (addr = strtok(tmp, ","); addr != NULL; addr = strtok(NULL, ",")) {
		len++;
	}
	if (len == 0)
		return len;				/* Nothing to parse */

	struct sockaddr_in6* res = calloc(len, sizeof(struct sockaddr_in6));
	*addrs = (struct sockaddr*)res;
	strcpy(tmp, str);
	for (addr = strtok(tmp, ","); addr != NULL; addr = strtok(NULL, ",")) {
		if (parseAddress(addr, port, res) != 0) {
			free(*addrs);
			*addrs = NULL;
			return -1;
		}
		res->sin6_port = htons(port);
		res++;
	}
	return len;
}

void printAddrs(char const* prefix, struct sockaddr const* addrs, int cnt)
{
	char addr[INET6_ADDRSTRLEN];
	char const* res;
	unsigned short port;
	while (cnt-- > 0) {
		switch (addrs->sa_family) {
		case AF_INET: {
			struct sockaddr_in const* a = (struct sockaddr_in const*)addrs;
			port = ntohs(a->sin_port);
			res = inet_ntop(AF_INET, &a->sin_addr, addr, INET6_ADDRSTRLEN);
			addrs = (void*)addrs + sizeof(*a);
			break;
		}
		case AF_INET6: {
			struct sockaddr_in6 const* a = (struct sockaddr_in6 const*)addrs;
			port = ntohs(a->sin6_port);
			res = inet_ntop(AF_INET6, &a->sin6_addr, addr, INET6_ADDRSTRLEN);
			addrs = (void*)addrs + sizeof(*a);
			break;
		}
		default:
			warning("Address family %d\n", addrs->sa_family);
			res = NULL;
			addrs++;
		}
		if (res == NULL) {
			warning("inet_ntop %s\n", strerror(errno));
		} else {
			logp("%s%s,%d\n", prefix, res, port);
		}
	}
}
