/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include <log.h>
#include <ipaddr.h>
#include <cmd.h>
#include <die.h>

#include <stdlib.h>
#include <stdio.h>
#include <sys/socket.h>
#include <string.h>
#include <errno.h>
#include <netinet/sctp.h>
#include <unistd.h>

#define MAXMSG (1024*16)

static int cmdClient(int argc, char **argv)
{
	char const* addr = "::1";
	char const* laddr = "::1";
	char const* port = "6000";
	struct Option options[] = {
		{"help", NULL, 0,
		 "client [options]\n"
		 "  Start a client"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"addr", &addr, 0, "Server addresses (default ::1)"},
		{"laddr", &laddr, 0, "Local addresses (default ::1)"},
		{"port", &port, 0, "Port (default 6000)"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	loginit(stderr);

	if (atoi(port) == 0)
		die("Invalid port [%s]\n", port);
	struct sockaddr* addrs;
	int cnt = parseAddrs(addr, atoi(port), &addrs);
	if (cnt < 0)
		die("Invalid addresses [%s]\n", addr);
	struct sockaddr* laddrs;
	int lcnt = parseAddrs(laddr, 0, &laddrs);
	if (lcnt < 0)
		die("Invalid local addresses [%s]\n", laddr);

	int sd = socket(PF_INET6, SOCK_STREAM, IPPROTO_SCTP);
	if (sd < 0)
		die("socket %s\n", strerror(errno));

	if (sctp_bindx(sd, laddrs, lcnt, SCTP_BINDX_ADD_ADDR) != 0)
		die("sctp_bindx %s\n", strerror(errno));

	if (sctp_connectx(sd, addrs, cnt, NULL) != 0)
		die("sctp_connectx %s\n", strerror(errno));

	INFO{
		logf("Connected\n");
		struct sockaddr* addrs;
		int cnt;
		cnt = sctp_getladdrs(sd, 0, &addrs);
		if (cnt <= 0)
			die("sctp_getladdrs %d\n", cnt);
		logf("Local addresses\n");
		printAddrs("  ", addrs, cnt);
		sctp_freeladdrs(addrs);
		cnt = sctp_getpaddrs(sd, 0, &addrs);
		if (cnt <= 0)
			die("sctp_getpaddrs %d\n", cnt);
		logf("Peer addresses\n");
		printAddrs("  ", addrs, cnt);
		sctp_freepaddrs(addrs);		
	}

	char buf[MAXMSG];
	ssize_t rc;
	for (;;) {
		printf("send> "); fflush(stdout);
		if (fgets(buf, sizeof(buf), stdin) == NULL)
			break;
		rc = send(sd, buf, strlen(buf) + 1, 0);
		if (rc < 0)
			die("send %s\n", strerror(errno));
		if (rc != (strlen(buf) + 1))
			die("send incomplete %d expected %d\n", rc, strlen(buf) + 1);
		rc = recv(sd, buf, sizeof(buf), 0);
		if (rc < 0)
			die("recv %s\n", strerror(errno));
		if (rc == 0) {
			info("Connection closed\n");
			break;
		}
		buf[rc - 1] = 0;
		printf("recv> %s", buf);
	}

	close(sd);
	return 0;
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("client", cmdClient);
}
