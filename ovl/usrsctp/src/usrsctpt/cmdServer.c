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

static void* serverThread(void* arg);
struct serverThreadArg {
	struct socket *sock;
};

static int cmdServer(int argc, char **argv)
{
	struct socket *sock;
	struct sctp_udpencaps encaps;
	struct sctp_event event;
	uint16_t event_types[] = {SCTP_ASSOC_CHANGE,
	                          SCTP_PEER_ADDR_CHANGE,
	                          SCTP_REMOTE_ERROR,
	                          SCTP_SHUTDOWN_EVENT,
	                          SCTP_ADAPTATION_INDICATION,
	                          SCTP_PARTIAL_DELIVERY_EVENT};

	char const* laddr = "::1";
	char const* lport = "6000";
	char const* lencapport = "0";
	char const* rencapport = "0";
	struct Option options[] = {
		{"help", NULL, 0,
		 "server [options]\n"
		 "  Start a server"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"addr", &laddr, 0, "Numeric comma separated addresses (default ::1)"},
		{"port", &lport, 0, "Port (default 6000)"},
		{"lencapport", &lencapport, 0, "Local UDP encapsulation port (default 9899)"},
		{"rencapport", &rencapport, 0, "Remote UDP encapsulation port (default 0 == disabled)"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	loginit(stderr);

	if (atoi(lport) == 0)
		die("Invalid port [%s]\n", lport);

	warning("Usrserver; %s\n", __TIME__);
	usrsctp_init(atoi(lencapport), NULL, debug_printf_stack);
#ifdef SCTP_DEBUG
	usrsctp_sysctl_set_sctp_debug_on(SCTP_DEBUG_ALL);
#endif
	usrsctp_sysctl_set_sctp_blackhole(2);
	usrsctp_sysctl_set_sctp_no_csum_on_loopback(0);
	usrsctp_sysctl_set_sctp_heartbeat_interval_default(10000);
	usrsctp_sysctl_set_sctp_nat_lite(1);

	if ((sock = usrsctp_socket(AF_INET6, SOCK_STREAM, IPPROTO_SCTP, NULL, NULL, 0, NULL)) == NULL) {
		die("usrsctp_socket");
	}
	warning("usrsctp_socket succesful; %p\n", sock);

	const int on = 1;
	if (usrsctp_setsockopt(sock, IPPROTO_SCTP, SCTP_I_WANT_MAPPED_V4_ADDR, (const void*)&on, (socklen_t)sizeof(int)) < 0) {
		die("usrsctp_setsockopt SCTP_I_WANT_MAPPED_V4_ADDR %s\n", strerror(errno));
	}
	if (usrsctp_setsockopt(sock, IPPROTO_SCTP, SCTP_RECVRCVINFO, &on, (socklen_t)sizeof(int)) < 0) {
		die("usrsctp_setsockopt SCTP_RECVRCVINFO %s\n", strerror(errno));
	}
	if (atoi(rencapport) != 0) {
		memset(&encaps, 0, sizeof(struct sctp_udpencaps));
		encaps.sue_address.ss_family = AF_INET6;
		encaps.sue_port = htons(atoi(rencapport));
		if (usrsctp_setsockopt(sock, IPPROTO_SCTP, SCTP_REMOTE_UDP_ENCAPS_PORT, (const void*)&encaps, (socklen_t)sizeof(struct sctp_udpencaps)) < 0) {
			perror("usrsctp_setsockopt SCTP_REMOTE_UDP_ENCAPS_PORT");
		}
	}
	memset(&event, 0, sizeof(event));
	event.se_assoc_id = SCTP_FUTURE_ASSOC;
	event.se_on = 1;
	
	for (unsigned int i = 0; i < (unsigned int)(sizeof(event_types)/sizeof(uint16_t)); i++) {
		event.se_type = event_types[i];
		if (usrsctp_setsockopt(sock, IPPROTO_SCTP, SCTP_EVENT, &event, sizeof(struct sctp_event)) < 0) {
			perror("usrsctp_setsockopt SCTP_EVENT");
		}
	}
	struct sockaddr* addrs;
	int cnt = parseAddrs(laddr, atoi(lport), &addrs);
	if (cnt <= 0)
		die("Invalid (or no) addresses [%s]\n", laddr);
	debug("cnt %d\n", cnt);

	if (usrsctp_bindx(sock, addrs, cnt, SCTP_BINDX_ADD_ADDR) < 0) {
		die("usrsctp_bindx %s\n", strerror(errno));
	}
	if (usrsctp_listen(sock, 64) < 0) {
		die("usrsctp_listen %s\n", strerror(errno));
	}

	INFO{
		struct sockaddr* addrs;
		int cnt = usrsctp_getladdrs(sock, 0, &addrs);
		if (cnt <= 0)
			die("usrsctp_getladdrs %d\n", cnt);
		logf("Accepting connections on:\n");
		printAddrs("  ", addrs, cnt);
		usrsctp_freeladdrs(addrs);
	}

	for (;;) {
		struct serverThreadArg* arg = calloc(1, sizeof(*arg));
		struct sockaddr_in6 peer;
		memset(&peer, 0, sizeof(peer));
		socklen_t len = sizeof(peer);
		arg->sock = usrsctp_accept(sock, (struct sockaddr*)&peer, &len);
		if (arg->sock == NULL)
			die("usrsctp_accept %s\n", strerror(errno));
		INFO{
			logf("Got a new connection (%p) from\n", arg->sock);
			printAddrs("  ", (struct sockaddr*)&peer, 1);
		}

		INFO{
			struct sockaddr* addrs;
			int cnt;
			cnt = usrsctp_getladdrs(arg->sock, 0, &addrs);
			if (cnt <= 0)
				die("usrsctp_getladdrs %d\n", cnt);
			logf("Local addresses\n");
			printAddrs("  ", addrs, cnt);
			usrsctp_freeladdrs(addrs);		
		}

		pthread_t tid;
		if (pthread_create(&tid, NULL, serverThread, arg) != 0)
			die("pthread_create\n");
		if (pthread_detach(tid) != 0)
			die("pthread_detach\n");
	}

	usrsctp_close(sock);
	while (usrsctp_finish() != 0) {
		sleep(SLEEP);
	}
	return 0;
}

static void* serverThread(void* _arg)
{
	struct serverThreadArg* arg = _arg;
	INFO{
		logf("serverThread (%p).\n", arg->sock);
		struct sockaddr* addrs;
		int cnt;
		cnt = usrsctp_getladdrs(arg->sock, 0, &addrs);
		if (cnt <= 0)
			die("usrsctp_getladdrs %d\n", cnt);
		logf("Local addresses\n");
		printAddrs("  ", addrs, cnt);
		usrsctp_freeladdrs(addrs);
		cnt = usrsctp_getpaddrs(arg->sock, 0, &addrs);
		if (cnt <= 0)
			die("usrsctp_getpaddrs %d\n", cnt);
		logf("Peer addresses\n");
		printAddrs("  ", addrs, cnt);
		usrsctp_freepaddrs(addrs);
	}

	for (;;) {
		char buffer[MAXMSG];
		char name[INET6_ADDRSTRLEN];
		struct sockaddr_in6 addr;

		struct sctp_rcvinfo rcv_info;
		unsigned int infotype;

		socklen_t from_len = (socklen_t)sizeof(struct sockaddr_in6);
		int flags = 0;
		socklen_t infolen = (socklen_t)sizeof(struct sctp_rcvinfo);
		ssize_t n = usrsctp_recvv(arg->sock, (void*)buffer, MAXMSG, (struct sockaddr *) &addr, &from_len, (void *)&rcv_info,
							&infolen, &infotype, &flags);
		if (n > 0) {
			if (flags & MSG_NOTIFICATION) {
				printf("Notification of length %llu received.\n", (unsigned long long)n);
			} else {
				if (infotype == SCTP_RECVV_RCVINFO) {
					printf("Msg of length %llu received from %s:%u on stream %u with SSN %u and TSN %u, PPID %u, context %u, complete %d.\n",
							(unsigned long long)n,
							inet_ntop(AF_INET6, &addr.sin6_addr, name, INET6_ADDRSTRLEN), ntohs(addr.sin6_port),
							rcv_info.rcv_sid,
							rcv_info.rcv_ssn,
							rcv_info.rcv_tsn,
							(uint32_t)ntohl(rcv_info.rcv_ppid),
							rcv_info.rcv_context,
							(flags & MSG_EOR) ? 1 : 0);
					if (flags & MSG_EOR) {
						struct sctp_sndinfo snd_info;

						snd_info.snd_sid = rcv_info.rcv_sid;
						snd_info.snd_flags = 0;
						if (rcv_info.rcv_flags & SCTP_UNORDERED) {
							snd_info.snd_flags |= SCTP_UNORDERED;
						}
						snd_info.snd_ppid = rcv_info.rcv_ppid;
						snd_info.snd_context = 0;
						snd_info.snd_assoc_id = rcv_info.rcv_assoc_id;
						if (usrsctp_sendv(arg->sock, buffer, (size_t)n, NULL, 0, &snd_info, (socklen_t)sizeof(struct sctp_sndinfo), SCTP_SENDV_SNDINFO, 0) < 0) {
							perror("sctp_sendv");
						}
					}
				} else {
					printf("Msg of length %llu received from %s:%u, complete %d.\n",
							(unsigned long long)n,
							inet_ntop(AF_INET6, &addr.sin6_addr, name, INET6_ADDRSTRLEN), ntohs(addr.sin6_port),
							(flags & MSG_EOR) ? 1 : 0);
				}
			}
		} else {
			break;
		}
	}
	
	usrsctp_close(arg->sock);
	return NULL;
}


__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("server", cmdServer);
}
