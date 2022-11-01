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
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <unistd.h>

#include <usrsctp.h>
#define debug_printf_stack (void(*)(const char *, ...))printf

#define MAXMSG (1024*16)
#define SLEEP 1

static int cmdNoInteractiveClient(int argc, char **argv)
{
	char const* addr = "::1";
	char const* laddr = "::1";
	char const* port = "6000";
	char const* lport = "0";
	char const* lencapport = "0";
	struct Option options[] = {
		{"help", NULL, 0,
		 "niclient [options]\n"
		 "  Start a client"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"addr", &addr, 0, "Server addresses (default ::1)"},
		{"laddr", &laddr, 0, "Local addresses (default ::1)"},
		{"port", &port, 0, "Port (default 6000)"},
		{"lport", &lport, 0, "Local port (default 0)"},
		{"lencapport", &lencapport, 0, "Local UDP encapsulation port (default 9899)"},
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
	int lcnt = parseAddrs(laddr, atoi(lport), &laddrs);
	if (lcnt < 0)
		die("Invalid local addresses [%s]\n", laddr);

	usrsctp_init(atoi(lencapport), NULL, debug_printf_stack);
#ifdef SCTP_DEBUG
	usrsctp_sysctl_set_sctp_debug_on(SCTP_DEBUG_ALL);
#endif
	usrsctp_sysctl_set_sctp_blackhole(2);
	usrsctp_sysctl_set_sctp_no_csum_on_loopback(0);
	usrsctp_sysctl_set_sctp_heartbeat_interval_default(10000);

	struct socket* sock = usrsctp_socket(AF_INET6, SOCK_STREAM, IPPROTO_SCTP, NULL, NULL, 0, NULL);
	if (sock == NULL)
		die("usrsctp_socket %s\n", strerror(errno));

	if (usrsctp_bindx(sock, laddrs, lcnt, SCTP_BINDX_ADD_ADDR) != 0)
		die("usrsctp_bindx %s\n", strerror(errno));

	if (usrsctp_connectx(sock, addrs, cnt, NULL) != 0)
		die("usrsctp_connectx %s\n", strerror(errno));

	INFO{
		logf("Connected\n");
		struct sockaddr* addrs;
		int cnt;
		cnt = usrsctp_getladdrs(sock, 0, &addrs);
		if (cnt <= 0)
			die("usrsctp_getladdrs %d\n", cnt);
		logf("Local addresses\n");
		printAddrs("  ", addrs, cnt);
		usrsctp_freeladdrs(addrs);
		cnt = usrsctp_getpaddrs(sock, 0, &addrs);
		if (cnt <= 0)
			die("usrsctp_getpaddrs %d\n", cnt);
		logf("Primary peer addresses\n");
		printAddrs("  ", addrs, cnt);
		usrsctp_freepaddrs(addrs);		
	}

	char send_string[] = "It really doesn't matter";
	char buffer[MAXMSG];
	memset(&buffer, 0, sizeof(buffer));

	ssize_t rc;
	struct sctp_rcvinfo rcv_info;
	unsigned int infotype;
	socklen_t infolen = (socklen_t)sizeof(struct sctp_rcvinfo);
	int flags = 0;

	for (int i = 0; i < 10; i++) {
		strncpy(buffer, send_string, strlen(send_string));
		printf("send> %s\n", buffer); fflush(stdout);

		rc = usrsctp_sendv(sock, buffer, strlen(buffer), NULL, 0, NULL, 0, SCTP_SENDV_NOINFO, 0);
		if (rc < 0)
			die("usrsctp_sendv %s\n", strerror(errno));
		if (rc != (strlen(buffer)))
			die("send incomplete %d expected %d\n", rc, strlen(buffer));

		rc = usrsctp_recvv(sock, (void*)buffer, MAXMSG, NULL, NULL, &rcv_info, &infotype, &infolen, &flags);
		if (rc < 0)
			die("usrsctp_recvv %s\n", strerror(errno));
		if (rc == 0) {
			info("Connection closed\n");
			break;
		}
		buffer[rc - 1] = 0;
		printf("recv> %s\n", buffer); fflush(stdout);
		sleep(SLEEP);
	}

	usrsctp_close(sock);
	while (usrsctp_finish() != 0) {
		sleep(SLEEP);
	}
	return 0;
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("niclient", cmdNoInteractiveClient);
}
