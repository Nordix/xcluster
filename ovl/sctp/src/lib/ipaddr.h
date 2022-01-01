#pragma once
/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include <netinet/in.h>

// parseAddress parses one address. IPv4 address is returned as
// ipv4 mapped ipv6 address.
// returns 0 - success
int parseAddress(char const* str, int port, /*out*/struct sockaddr_in6* a);

// parseAddrs parses a comma-separated list of ip addresses. IPv4
// addresses are returned as ipv4 mapped ipv6 addresses.
// returns the number of addresses or -1 if failed.
int parseAddrs(char const* str, int port, /*out*/struct sockaddr** addrs);

// printAddrs Print the ip addresses. Non-ip addresses will cause
// unpredictable errors.
void printAddrs(char const* prefix, struct sockaddr const* addrs, int cnt);
