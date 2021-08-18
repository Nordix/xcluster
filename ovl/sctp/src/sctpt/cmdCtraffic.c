/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include <log.h>
#include <ipaddr.h>
#include <stats.h>
#include <cmd.h>
#include <die.h>
#include <shmem.h>

#include <stdlib.h>
#include <stdio.h>
#include <sys/socket.h>
#include <string.h>
#include <errno.h>
#include <netinet/sctp.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <poll.h>

#define MAXMSG (1024*16)

struct ThreadArg {
	unsigned id;
	pthread_t tid;
	int nAddr;
	struct sockaddr* addrs;
	int nLaddr;
	struct sockaddr* laddrs;
	struct Stats* stats;
	float rate;
};
static void* clientThread(void* arg);

static int quit = 0;
static void sighandler(int sig)
{
	quit = 1;
}
static void blockSignal(int sig)
{
	sigset_t mask;
	sigemptyset(&mask); 
	sigaddset(&mask, sig); 
	pthread_sigmask(SIG_BLOCK, &mask, NULL);
}


static int cmdCtraffic(int argc, char **argv)
{
	char const* addr = "::1";
	char const* laddr = "::1";
	char const* port = "6000";
	char const* rate = "1.0";
	char const* clients = "1";
	char const* duration = "10";
	char const* shm = "sctpstats";
	struct Option options[] = {
		{"help", NULL, 0,
		 "ctraffic [options]\n"
		 "  Generate continuous traffic"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"shm", &shm, 0, "Stats shared mem"},
		{"addr", &addr, 0, "Server addresses (default ::1)"},
		{"laddr", &laddr, 0, "Local addresses (default ::1)"},
		{"port", &port, 0, "Port (default 6000)"},
		{"clients", &clients, 0, "Number of clients (default 1)"},
		{"rate", &rate, 0, "Rate in pkt/S (default 1.0)"},
		{"duration", &duration, 0, "Duration in seconds (default 10)"},		
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

	struct Stats* stats = mapSharedDataOrDie(shm, O_RDWR);
	stats_init(stats, stats->nBuckets, stats->interval);

	// Start client threads
	int nclients = atoi(clients);
	if (nclients < 1)
		die("No clients");
	struct ThreadArg* targs = calloc(nclients, sizeof(struct ThreadArg));
	if (targs == NULL) die("OOM");
	for (int i = 0; i < nclients; i++) {
		struct ThreadArg* targ = targs + i;
		targ->id = i;
		targ->nAddr = cnt;
		targ->addrs = addrs;
		targ->nLaddr = lcnt;
		targ->laddrs = laddrs;
		targ->stats = stats;
		if (pthread_create(&targ->tid, NULL, clientThread, targ) != 0)
			die("pthread_create\n");
		debug("Client %u started as tid=%lu\n", targ->id, targ->tid);
	}

	/*
	  Signal thread control;
	  SIGTERM and SIGINT are caught by the main thread and blocked in clients.
	  SIGUSR1 is blocked in the main thread and caught in the clients.
	*/
	signal(SIGTERM, sighandler);
	signal(SIGINT, sighandler);
	signal(SIGUSR1, sighandler);
	blockSignal(SIGUSR1);

	// A SIGTERM will break the sleep. Restore signal handling so the
	// process can be terminated in case of a block.
	if (!quit) sleep(atoi(duration));
	signal(SIGTERM, SIG_DFL);
	signal(SIGINT, SIG_DFL);
	if (quit) info("Signal was received\n");
	
	// Terminate all client threads
	for (int i = 0; i < nclients; i++) {
		struct ThreadArg* targ = targs + i;
		debug("Send SIGUSR1 to client %u (tid=%lu)\n", targ->id, targ->tid);
		(void)pthread_kill(targ->tid, SIGUSR1);
	}
	debug("Waiting for client threads\n");
	for (int i = 0; i < nclients; i++) {
		(void)pthread_join(targs[i].tid, NULL);
	}
	debug("All client threads terminated\n");

	return 0;
}

static int cmdStats(int argc, char **argv)
{
	char const* buckets = "16";
	char const* interval = "1000";
	char const* shm = "sctpstats";
	struct Option options[] = {
		{"help", NULL, 0,
		 "stats [options] (init|clear|show|json)\n"
		 "  Handle continuous traffic statistics"},
		{"log", &loglevelarg, 0, "Log level 0-7"},
		{"shm", &shm, 0, "Stats shared mem"},
		{"buckets", &buckets, 0, "Number of buckets for the histogram"},
		{"interval", &interval, 0, "Interval in histogram (micro S)"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptionsOrDie(argc, argv, options);
	loginit(stderr);
	argc -= nopt;
	argv += nopt;
	debug("Cmd: %s\n", argc > 0 ? *argv : "(none)");
	if (argc == 0 || strcmp(*argv, "show") == 0) {
		struct Stats const* s = mapSharedDataOrDie(shm, O_RDONLY);
		stats_print(stdout, s);
		return 0;
	}
	if (strcmp(*argv, "init") == 0) {
		int nbuckets = atoi(buckets);
		if (nbuckets < 1)
			die("Too few buckets\n");
		int delta = atoi(interval);
		if (delta < 1)
			die("Too small interval\n");
		unsigned len = sizeof(struct Stats) + nbuckets * sizeof(unsigned);
		char buf[len];
		stats_init(buf, nbuckets, delta);
		createSharedDataOrDie(shm, buf, len);
		return 0;
	}
	if (strcmp(*argv, "clear") == 0) {
		struct Stats* s = mapSharedDataOrDie(shm, O_RDWR);
		int delta = atoi(interval);
		if (delta < 1)
			die("Too small interval\n");
		stats_init(s, s->nBuckets, delta);
		return 0;
	}
	if (strcmp(*argv, "json") == 0) {
		struct Stats const* s = mapSharedDataOrDie(shm, O_RDONLY);
		stats_print_json(stdout, s);
		return 0;
	}

	die("Invalid command: %s\n", *argv);
	return 0;
}
__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("ctraffic", cmdCtraffic);
	addCmd("stats", cmdStats);
}


static void* clientThread(void* _arg)
{
	/*
	  Block SIGTERM and SIGINT to allow the main thread to handle it
	  and wake up client threads with a SIGUSR1.
	 */
	blockSignal(SIGTERM);
	blockSignal(SIGINT);

	struct ThreadArg* arg = _arg;
	int sd = socket(PF_INET6, SOCK_STREAM, IPPROTO_SCTP);
	if (sd < 0)
		die("socket %s\n", strerror(errno));

	if (sctp_bindx(sd, arg->laddrs, arg->nLaddr, SCTP_BINDX_ADD_ADDR) != 0)
		die("sctp_bindx %s\n", strerror(errno));

	if (sctp_connectx(sd, arg->addrs, arg->nAddr, NULL) != 0) {
		warning("sctp_connectx %s\n", strerror(errno));
		return NULL;
	}

	DEBUG{
		logf("Client %u: Connected\n", arg->id);
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
	struct pollfd pfd;
	struct timespec now;
	int timeout = 200; //throttle_init(arg->rate);
	for (;;) {
		pfd.fd = sd;
		pfd.events = POLLIN;
		pfd.revents = 0;
		rc = poll(&pfd, 1, timeout);
		if (rc < 0) {
			/* signal. Wait an extra 100mS for the last packet */
			timeout = 100;
			continue;
		}
		clock_gettime(CLOCK_MONOTONIC, &now);
		if (rc == 0) {
			/* Timeout. Time to send a packet */
			if (quit)
				break;			/* We are quitting */
			stats_packet_init(arg->stats, &now, buf, 1024);
			rc = send(sd, buf, 1024, 0);
			if (rc < 0)
				die("send %s\n", strerror(errno));
			if (rc != 1024)
				die("send incomplete %d expected %d\n", rc, 1024);
		} else {
			rc = recv(sd, buf, sizeof(buf), 0);
			if (rc < 0)
				die("recv %s\n", strerror(errno));
			if (rc == 0) {
				info("Connection closed\n");
				break;
			}
			stats_packet_record(arg->stats, &now, buf, rc);
			if (quit)
				break;			/* We are quitting */
		}
	}

	debug("Client %u: terminating...\n", arg->id);
	close(sd);
	return NULL;
}
