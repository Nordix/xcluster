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
#include <pthread.h>
#include <unistd.h>

#define MAXMSG (1024*16)

static void* serverThread(void* arg);
struct serverThreadArg {
	int sd;
};

static int cmdServer(int argc, char **argv)
{
	char const* addr = "::1";
	char const* port = "6000";
	struct Option options[] = {
		{"help", NULL, 0,
		 "server [options]\n"
		 "  Start a server"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"addr", &addr, 0, "Numeric comma separated addresses (default ::1)"},
		{"port", &port, 0, "Port (default 6000)"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	loginit(stderr);

	if (atoi(port) == 0)
		die("Invalid port [%s]\n", port);
	struct sockaddr* addrs;
	int cnt = parseAddrs(addr, atoi(port), &addrs);
	if (cnt <= 0)
		die("Invalid (or no) addresses [%s]\n", addr);
	debug("cnt %d\n", cnt);

	int sd = socket(PF_INET6, SOCK_STREAM, IPPROTO_SCTP);
	if (sd < 0)
		die("socket %s\n", strerror(errno));
	if (sctp_bindx(sd, addrs, cnt, SCTP_BINDX_ADD_ADDR) != 0)
		die("sctp_bindx %s\n", strerror(errno));
	if (listen(sd, 64) != 0)
		die("listen %s\n", strerror(errno));

	INFO{
		struct sockaddr* addrs;
		int cnt = sctp_getladdrs(sd, 0, &addrs);
		if (cnt <= 0)
			die("sctp_getladdrs %d\n", cnt);
		logf("Accepting connections on:\n");
		printAddrs("  ", addrs, cnt);
		sctp_freeladdrs(addrs);
	}

	for (;;) {
		struct serverThreadArg* arg = calloc(1, sizeof(*arg));
		struct sockaddr_in6 peer;
		socklen_t len = sizeof(peer);
		arg->sd = accept(sd, (struct sockaddr*)&peer, &len);
		if (arg->sd < 0)
			die("accept %s\n", strerror(errno));
		INFO{
			logf("Got a new connection (%d) from\n", arg->sd);
			printAddrs("  ", (struct sockaddr*)&peer, 1);
		}

		pthread_t tid;
		if (pthread_create(&tid, NULL, serverThread, arg) != 0)
			die("pthread_create\n");
		if (pthread_detach(tid) != 0)
			die("pthread_detach\n");
	}
	return 0;
}

static void* serverThread(void* _arg)
{
	struct serverThreadArg* arg = _arg;
	INFO{
		logf("serverThread (%d).\n", arg->sd);
		struct sockaddr* addrs;
		int cnt;
		cnt = sctp_getladdrs(arg->sd, 0, &addrs);
		if (cnt <= 0)
			die("sctp_getladdrs %d\n", cnt);
		logf("Local addresses\n");
		printAddrs("  ", addrs, cnt);
		sctp_freeladdrs(addrs);
		cnt = sctp_getpaddrs(arg->sd, 0, &addrs);
		if (cnt <= 0)
			die("sctp_getpaddrs %d\n", cnt);
		logf("Peer addresses\n");
		printAddrs("  ", addrs, cnt);
		sctp_freepaddrs(addrs);
	}

	char buf[MAXMSG];
	ssize_t rc;
	for (;;) {
		rc = recv(arg->sd, buf, sizeof(buf), 0);
		if (rc < 0)
			die("recv %s\n", strerror(errno));
		if (rc == 0) {
			printf("Connection closed\n");
			break;
		}

		int cnt = send(arg->sd, buf, rc, 0);
		if (cnt < 0)
			die("send %s\n", strerror(errno));
		if (cnt != rc)
			die("send incomplete %d expected %d\n", cnt, rc);
	}
	
	close(arg->sd);
	return NULL;
}


__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("server", cmdServer);
}
