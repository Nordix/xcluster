/* Taken from dpdk-20.11/examples/skeleton/
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2010-2015 Intel Corporation
 */

#include <stdint.h>
#include <inttypes.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>

#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024

#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32

static const struct rte_eth_conf port_conf_default = {
	.rxmode = {
		.max_rx_pkt_len = RTE_ETHER_MAX_LEN,
	},
};

/* basicfwd.c: Basic DPDK skeleton forwarding example. */

/*
 * Initializes a given port using global settings and with the RX buffers
 * coming from the mbuf_pool passed as a parameter.
 */
static int
port_init(uint16_t port, struct rte_mempool *mbuf_pool)
{
	struct rte_eth_conf port_conf = port_conf_default;
	const uint16_t rx_rings = 1, tx_rings = 1;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;
	struct rte_eth_dev_info dev_info;
	struct rte_eth_txconf txconf;

	if (!rte_eth_dev_is_valid_port(port))
		return -1;

	retval = rte_eth_dev_info_get(port, &dev_info);
	if (retval != 0) {
		printf("Error during getting device (port %u) info: %s\n",
				port, strerror(-retval));
		return retval;
	}

	if (dev_info.tx_offload_capa & DEV_TX_OFFLOAD_MBUF_FAST_FREE)
		port_conf.txmode.offloads |=
			DEV_TX_OFFLOAD_MBUF_FAST_FREE;

	/* Configure the Ethernet device. */
	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
		return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	/* Allocate and set up 1 RX queue per Ethernet port. */
	for (q = 0; q < rx_rings; q++) {
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
				rte_eth_dev_socket_id(port), NULL, mbuf_pool);
		if (retval < 0)
			return retval;
	}

	txconf = dev_info.default_txconf;
	txconf.offloads = port_conf.txmode.offloads;
	/* Allocate and set up 1 TX queue per Ethernet port. */
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), &txconf);
		if (retval < 0)
			return retval;
	}

	/* Start the Ethernet port. */
	retval = rte_eth_dev_start(port);
	if (retval < 0)
		return retval;

	/* Display the port MAC address. */
	struct rte_ether_addr addr;
	retval = rte_eth_macaddr_get(port, &addr);
	if (retval != 0)
		return retval;

	printf("Port %u MAC: %02" PRIx8 " %02" PRIx8 " %02" PRIx8
			   " %02" PRIx8 " %02" PRIx8 " %02" PRIx8 "\n",
			port,
			addr.addr_bytes[0], addr.addr_bytes[1],
			addr.addr_bytes[2], addr.addr_bytes[3],
			addr.addr_bytes[4], addr.addr_bytes[5]);
#if 0
	/* Enable RX in promiscuous mode for the Ethernet device. */
	retval = rte_eth_promiscuous_enable(port);
	if (retval != 0)
		return retval;
#endif
	return 0;
}

/*
 * The lcore main. This is the main thread that does the work, reading from
 * an input port and writing to an output port.
 */
static __rte_noreturn void
lcore_main(void)
{
	uint16_t port;

	/*
	 * Check that the port is on the same NUMA node as the polling thread
	 * for best performance.
	 */
	RTE_ETH_FOREACH_DEV(port)
		if (rte_eth_dev_socket_id(port) > 0 &&
				rte_eth_dev_socket_id(port) !=
						(int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread.\n\tPerformance will "
					"not be optimal.\n", port);

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n",
			rte_lcore_id());

	/* Run until the application is quit or killed. */
	for (;;) {
		/*
		 * Receive packets on a port and forward them on the paired
		 * port. The mapping is 0 -> 1, 1 -> 0, 2 -> 3, 3 -> 2, etc.
		 */
		RTE_ETH_FOREACH_DEV(port) {

			/* Get burst of RX packets, from first port of pair. */
			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, 0,
					bufs, BURST_SIZE);

			if (unlikely(nb_rx == 0))
				continue;

			/* Send burst of TX packets, to second port of pair. */
			const uint16_t nb_tx = rte_eth_tx_burst(port ^ 1, 0,
					bufs, nb_rx);

			/* Free any unsent packets. */
			if (unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
}

/*
 * The main function, which does initialization and calls the per-lcore
 * functions.
 */
int
basicfwd_main(int argc, char *argv[])
{
	struct rte_mempool *mbuf_pool;
	unsigned nb_ports;
	uint16_t portid;

	/* Initialize the Environment Abstraction Layer (EAL). */
	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");

	argc -= ret;
	argv += ret;

	/* Check that there is an even number of ports to send/receive on. */
	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports < 2 || (nb_ports & 1))
		rte_exit(EXIT_FAILURE, "Error: number of ports must be even\n");

	/* Creates a new mempool in memory to hold the mbufs. */
	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS * nb_ports,
		MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());

	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/* Initialize all ports. */
	RTE_ETH_FOREACH_DEV(portid)
		if (port_init(portid, mbuf_pool) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16 "\n",
					portid);

	if (rte_lcore_count() > 1)
		printf("\nWARNING: Too many lcores enabled. Only 1 used.\n");

	/* Call lcore_main on the main core only. */
	lcore_main();

	return 0;
}

/* ======== END OF dpdk-20.11/examples/skeleton/
   From now on;
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"

#define IP_HEADER(b) rte_pktmbuf_mtod_offset(b, uint8_t*, RTE_ETHER_HDR_LEN)
#define IP_LEN(b) (b)->data_len - RTE_ETHER_HDR_LEN

struct SharedData {
	struct MagData m;
	struct rte_ether_addr target[MAX_N];
};
static char const* const defaultShmName = "l2lb";

static int init(int argc, char* argv[])
{
	struct rte_mempool *mbuf_pool;
	unsigned nb_ports;
	uint16_t portid;

	/* Initialize the Environment Abstraction Layer (EAL). */
	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");

	/* Check that there is 2 ports */
	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports != 2)
		rte_exit(EXIT_FAILURE, "Error: number of ports must be 2\n");

	/* Creates a new mempool in memory to hold the mbufs. */
	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS * nb_ports,
		MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());

	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/* Initialize all ports. */
	RTE_ETH_FOREACH_DEV(portid)
		if (port_init(portid, mbuf_pool) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16 "\n",
					portid);

	if (rte_lcore_count() > 1)
		printf("\nWARNING: Too many lcores enabled. Only 1 used.\n");

	return ret;
}

static void printMbuf(uint16_t port, struct rte_mbuf* b)
{
	struct rte_ether_hdr* eth = rte_pktmbuf_mtod(
		b, struct rte_ether_hdr *);
	printf(
		"%u (%u,%u): %s -> %s, %04x\n", port, b->pkt_len, b->data_len,
		macToString(eth->s_addr.addr_bytes),
		macToString(eth->d_addr.addr_bytes), ntohs(eth->ether_type));
	switch (ntohs(eth->ether_type)) {
	case RTE_ETHER_TYPE_IPV4:
		ipv4Print(IP_LEN(b), IP_HEADER(b));
		break;
	case RTE_ETHER_TYPE_IPV6:
		ipv6Print(IP_LEN(b), IP_HEADER(b));		
		break;
	default:;
	}
}

// Decrement ttl, Check and re-compute csums
static int ttlCsum(struct rte_mbuf* b)
{
	struct rte_ether_hdr* eth = rte_pktmbuf_mtod(
		b, struct rte_ether_hdr *);

	if (ntohs(eth->ether_type) == RTE_ETHER_TYPE_IPV4) {
		// Decrement ttl
		struct rte_ipv4_hdr* ipv4_hdr =
			rte_pktmbuf_mtod_offset(b, struct rte_ipv4_hdr*, RTE_ETHER_HDR_LEN);
		if (ipv4_hdr->time_to_live <= 1) {
			return 1;
		}
		ipv4_hdr->time_to_live--;
		ipv4_hdr->hdr_checksum = 0;

		void* l4hdr = (uint8_t*)ipv4_hdr + rte_ipv4_hdr_len(ipv4_hdr);
		uint8_t proto = ipv4_hdr->next_proto_id;
		if (proto == IPPROTO_TCP) {
			((struct rte_tcp_hdr*)l4hdr)->cksum = 0;
			((struct rte_tcp_hdr*)l4hdr)->cksum =
				rte_ipv4_udptcp_cksum(ipv4_hdr, l4hdr);
		} else if (proto == IPPROTO_UDP) {
			((struct rte_udp_hdr*)l4hdr)->dgram_cksum = 0;
			((struct rte_udp_hdr*)l4hdr)->dgram_cksum =
				rte_ipv4_udptcp_cksum(ipv4_hdr, l4hdr);
		}
		ipv4_hdr->hdr_checksum = rte_ipv4_cksum(ipv4_hdr);
	}
	return 0;
}


static int cmdFwd(int argc, char* argv[])
{
	int ret = init(argc, argv);
	argc -= ret;
	argv += ret;

	char const* shmName = defaultShmName;
	char const* mac0;
	char const* mac1;
	struct Option options[] = {
		{"help", NULL, 0,
		 "fwd [dpdk-eal-options] -- [options]\n"
		 "  Forward traffic"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{"mac0", &mac0, REQUIRED, "Downstream MAC address (server)"},
		{"mac1", &mac1, REQUIRED, "Upstream MAC address (client)"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;
	
	/*
	  struct rte_ether_addr {
	    uint8_t addr_bytes[RTE_ETHER_ADDR_LEN];
	  } __rte_aligned(2);
	*/
	struct rte_ether_addr dst0, dst1;
	macParseOrDie(mac0, dst0.addr_bytes);
	macParseOrDie(mac1, dst1.addr_bytes);

	// Get the source MAC addresses
	struct rte_ether_addr src0, src1;
	(void)rte_eth_macaddr_get(0, &src0);
	(void)rte_eth_macaddr_get(1, &src1);

	printf(
		"\nCore %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());

	uint16_t port;
	for (;;) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(
				port, 0, bufs, BURST_SIZE);

			if (unlikely(nb_rx == 0))
				continue;

			for (uint16_t i = 0; i < nb_rx; i++) {
				struct rte_mbuf* b = bufs[i];
				ttlCsum(b);
				printMbuf(port, b);
				struct rte_ether_hdr *eth;
				eth = rte_pktmbuf_mtod(bufs[i], struct rte_ether_hdr *);
				if (port == 0) {
					// We shall send on port 1
					rte_ether_addr_copy(&src1, &eth->s_addr);
					rte_ether_addr_copy(&dst1, &eth->d_addr);
				} else {
					rte_ether_addr_copy(&src0, &eth->s_addr);
					rte_ether_addr_copy(&dst0, &eth->d_addr);
				}
			}
			
			/* Send burst of TX packets, to second port of pair. */
			const uint16_t nb_tx = rte_eth_tx_burst(
				port ^ 1, 0, bufs, nb_rx);

			/* Free any unsent packets. */
			if (unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
	
	return 0;
}

static int cmdInit(int argc, char* argv[])
{
	char const* shmName = defaultShmName;
	struct Option options[] = {
		{"help", NULL, 0,
		 "init [options]\n"
		 "  Initiate the shm structure"},
		{"shm", &shmName, 0, "Shared memory struct to create"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;

	struct SharedData sh;
	memset(&sh, 0, sizeof(sh));
	maglevInit(&sh.m);
	createSharedDataOrDie(shmName, &sh, sizeof(sh)); 
	return 0;
}

static int cmdShow(int argc, char* argv[])
{
	char const* shmName = defaultShmName;
	struct Option options[] = {
		{"help", NULL, 0,
		 "show [options]\n"
		 "  Show LB status"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;

	struct SharedData* sh = mapSharedDataOrDie(
		shmName, sizeof(struct SharedData), O_RDONLY);
	printf("M=%u, N=%u, lookup;\n", sh->m.M, sh->m.N);
	for (int i = 0; i < 24; i++) {
		printf("%d ", sh->m.lookup[i]);
	}
	printf("...\n");
	printf("Active:\n");
	for (int i = 0; i < sh->m.N; i++) {
		if (sh->m.active[i] == 0)
			continue;
		printf("  %-2d: %s\n", i, macToString(sh->target[i].addr_bytes));
	}
	return 0;
}

static int setActive(int argc, char* argv[], int v)
{
	char const* shmName = defaultShmName;
	char const* mac = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "(de)activate [options] <index>\n"
		 "  Activate/deactivate a target"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{"mac", &mac, 0, "MAC address for the target"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;
	argc -= nopt;
	argv += nopt;
	
	if (argc < 1) {
		printf("No index\n");
		return 0;
	}
	unsigned i = atoi(argv[0]);

	struct SharedData* sh = mapSharedDataOrDie(
		shmName, sizeof(struct SharedData), O_RDWR);

	if (i >= sh->m.N) {
		printf("Invalid index [%u]\n", i);
		return 1;
	}

	if (mac != NULL) {
		macParseOrDie(mac, sh->target[i].addr_bytes);
	}
	if (v >= 0) {
		sh->m.active[i] = v;
		populate(&sh->m);
	}
	return 0;
}
static int cmdActivate(int argc, char* argv[])
{
	return setActive(argc, argv, 1);
}
static int cmdDeactivate(int argc, char* argv[])
{
	return setActive(argc, argv, 0);
}

static int cmdLb(int argc, char* argv[])
{
	int ret = init(argc, argv);
	argc -= ret;
	argv += ret;

	char const* shmName = defaultShmName;
	char const* vip4;
	char const* vip6;
	char const* mac1;
	struct Option options[] = {
		{"help", NULL, 0,
		 "lb [dpdk-eal-options] -- [options]\n"
		 "  Start load-balancing"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{"mac1", &mac1, REQUIRED, "Dest MAC address for reply packets"},
		{"vip4", &vip4, REQUIRED, "IPv4 Virtual IP"},
		{"vip6", &vip6, REQUIRED, "IPv6 Virtual IP"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;


	/*
	  struct rte_ether_addr {
	    uint8_t addr_bytes[RTE_ETHER_ADDR_LEN];
	  } __rte_aligned(2);
	*/
	struct rte_ether_addr dst1;
	macParseOrDie(mac1, dst1.addr_bytes);

	struct SharedData* sh = mapSharedDataOrDie(
		shmName, sizeof(struct SharedData), O_RDONLY);

	// Get the source MAC addresses
	struct rte_ether_addr src0, src1;
#if 1
	(void)rte_eth_macaddr_get(0, &src0);
	(void)rte_eth_macaddr_get(1, &src1);
#else
	macParseOrDie("0:0:0:1:1:c9", src0.addr_bytes);
	macParseOrDie("0:0:0:1:2:c9", src1.addr_bytes);
#endif
	printf(
		"\nCore %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());
	/* Run until the application is quit or killed. */
	uint16_t port;
	for (;;) {
		RTE_ETH_FOREACH_DEV(port) {

			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(
				port, 0, bufs, BURST_SIZE);

			if (unlikely(nb_rx == 0))
				continue;

			for (uint16_t i = 0; i < nb_rx; i++) {
				struct rte_mbuf* b = bufs[i];
				struct rte_ether_hdr *eth;
				if (ttlCsum(b) != 0) {
					// TODO; Discard packet with ttl==0
				}
				eth = rte_pktmbuf_mtod(b, struct rte_ether_hdr *);
				if (port == 0) {
					// We shall send on port 1
					rte_ether_addr_copy(&src1, &eth->s_addr);
					rte_ether_addr_copy(&dst1, &eth->d_addr);
				} else {
					// We shall load_balance
					rte_ether_addr_copy(&src0, &eth->s_addr);
					unsigned hash = 0;
					uint16_t type = ntohs(eth->ether_type);
					if (type == RTE_ETHER_TYPE_IPV4)
						hash = ipv4Hash(IP_LEN(b), IP_HEADER(b));
					int i = sh->m.lookup[hash % sh->m.M];
					if (i >= 0) {
						rte_ether_addr_copy(&sh->target[i], &eth->d_addr);
					} else {
						// No destinations! TODO: Discard packet.
						memset(&eth->d_addr, 0 , sizeof(eth->d_addr));
					}
				}
			}
			
			/* Send burst of TX packets, to second port of pair. */
			const uint16_t nb_tx = rte_eth_tx_burst(
				port ^ 1, 0, bufs, nb_rx);

			/* Free any unsent packets. */
			if (unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
	
	return 0;
}



int main(int argc, char *argv[])
{
	static struct Cmd {
		char const* const name;
		int (*fn)(int argc, char* argv[]);
	} cmd[] = {
		{"basicfwd", basicfwd_main},
		{"fwd", cmdFwd},
		{"init", cmdInit},
		{"activate", cmdActivate},
		{"deactivate", cmdDeactivate},
		{"show", cmdShow},
		{"lb", cmdLb},
		{NULL, NULL}
	};

	if (argc < 2) {
		printf("Usage: %s <command> [opt...]\n", argv[0]);
		for (struct Cmd const* c = cmd; c->name != NULL; c++) {
			printf("  %s\n", c->name);
		}
		exit(EXIT_FAILURE);
	}

	argc--;
	argv++;
	for (struct Cmd* c = cmd; c->fn != NULL; c++) {
		if (strcmp(*argv, c->name) == 0)
			return c->fn(argc, argv);
	}

	printf("Uknnown command [%s]\n", *argv);
	return 1;
}

