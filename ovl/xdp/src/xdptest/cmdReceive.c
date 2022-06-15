/* 
   SPDX-License-Identifier: MIT
   Copyright (c) Nordix Foundation
*/

#include <cmd.h>
#include <die.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
#include <unistd.h>
#include <bpf/xsk.h>
#include <net/if.h>
#include <linux/if_ether.h>
#include <arpa/inet.h>

#define D(x)
#define Dx(x) x

// This struct is used in xdp-tutorial and kernel sample
struct xsk_umem_info {
	struct xsk_ring_prod fq;
	struct xsk_ring_cons cq;
	struct xsk_umem *umem;
	void *buffer;
};

static struct xsk_umem_info* create_umem(unsigned nfq)
{
	struct xsk_umem_info* u;
	u = calloc(1, sizeof(*u));

// XSK_RING_PROD__DEFAULT_NUM_DESCS=2048
#define NUM_FRAMES XSK_RING_PROD__DEFAULT_NUM_DESCS

	uint64_t buffer_size = XSK_UMEM__DEFAULT_FRAME_SIZE * NUM_FRAMES;
	if (posix_memalign(&u->buffer, getpagesize(), buffer_size) != 0)
		die("Can't allocate buffer memory [%s]\n", strerror(errno));
	int rc = xsk_umem__create(
		&u->umem, u->buffer, buffer_size, &u->fq, &u->cq, NULL);
	if (rc != 0)
		die("Failed to create umem; %s\n", strerror(-rc));

	uint32_t idx;
	rc = xsk_ring_prod__reserve(&u->fq, nfq, &idx);
	if (rc != nfq)
		die("Failed xsk_ring_prod__reserve; %s\n", strerror(-rc));
	Dx(printf("UMEM fq; reserved %u, idx = %u\n", nfq, idx));
	int i;
	for (i = 0; i < nfq; i++, idx++) {
		*xsk_ring_prod__fill_addr(&u->fq, idx) = i * XSK_UMEM__DEFAULT_FRAME_SIZE;
	}
	xsk_ring_prod__submit(&u->fq, nfq);

	return u;
}

static void load_xdp_program(int ifindex, char xdp_filename[], struct bpf_object **obj)
{
	struct bpf_prog_load_attr prog_load_attr = {
		.prog_type      = BPF_PROG_TYPE_XDP,
		.file 			= xdp_filename,
	};

	int prog_fd;
	if (bpf_prog_load_xattr(&prog_load_attr, obj, &prog_fd))
		exit(EXIT_FAILURE);
	if (prog_fd < 0) {
		fprintf(stderr, "ERROR: no program found: %s\n",
			strerror(prog_fd));
		exit(EXIT_FAILURE);
	}

	if (bpf_xdp_attach(ifindex, prog_fd, 0, NULL) < 0) {
		fprintf(stderr, "ERROR: link set xdp fd failed\n");
		exit(EXIT_FAILURE);
	}
}

static void enter_xsks_into_map(struct xsk_socket *xsk, int queue, struct bpf_object *obj)
{
	struct bpf_map *map;
	int xsks_map;

	map = bpf_object__find_map_by_name(obj, "xsks_map");
	xsks_map = bpf_map__fd(map);
	if (xsks_map < 0) {
		fprintf(stderr, "ERROR: no xsks map found: %s\n",
			strerror(xsks_map));
			exit(EXIT_FAILURE);
	}

	int fd = xsk_socket__fd(xsk);
	int ret = bpf_map_update_elem(xsks_map, &queue, &fd, 0);
	if (ret) {
		fprintf(stderr, "ERROR: bpf_map_update_elem %d\n", queue);
		exit(EXIT_FAILURE);
	}
}

static int cmdReceive(int argc, char **argv)
{
	char const* dev;
	char const* queue = NULL;
	char const* fillq = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "receive [options]\n"
		 "  Use an AF_XDP socket to receive packets"},
		{"dev", &dev, REQUIRED,
		 "The device to use"},
		{"queue", &queue, 0,
		 "The RX queue to use. Default 0"},
		{"fillq", &fillq, 0,
		 "UMEM buffers in the fill queue. Default 512"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptionsOrDie(argc, argv, options);
	argc -= nopt;
	argv += nopt;
	unsigned int ifindex = if_nametoindex(dev);
	if (ifindex == 0)
		die("Unknown interface [%s]\n", dev);
	int q = 0;
	if (queue != NULL)
		q = atoi(queue);
	unsigned nfq = 512;
	if (fillq != NULL)
		nfq = atoi(fillq);

	// (just checking?)
	uint32_t prog_id = 0;
	int rc;
	rc = bpf_get_link_xdp_id(ifindex, &prog_id, 0);
	if (rc != 0)
		die("Failed bpf_get_link_xdp_id ingress; %s\n", strerror(-rc));

	struct xsk_umem_info* uinfo = create_umem(nfq);
	struct xsk_socket_config xsk_cfg;

	struct xsk_socket *ixsk;
	struct xsk_ring_cons rx;
	struct xsk_ring_prod tx;
	xsk_cfg.rx_size = XSK_RING_CONS__DEFAULT_NUM_DESCS;
	xsk_cfg.tx_size = XSK_RING_PROD__DEFAULT_NUM_DESCS;
	xsk_cfg.libbpf_flags = XSK_LIBBPF_FLAGS__INHIBIT_PROG_LOAD;
	xsk_cfg.xdp_flags = 0;
	xsk_cfg.bind_flags = XDP_COPY;
	rc = xsk_socket__create(&ixsk, dev, q, uinfo->umem, &rx, &tx, &xsk_cfg);
	if (rc != 0)
		die("Failed xsk_socket__create (ingress); %s\n", strerror(-rc));
	Dx(printf("Need wakeup; %s\n", xsk_ring_prod__needs_wakeup(&tx) ? "Yes":"No"));

	struct bpf_object *xdp_object;
	char xdp_filename[256];
	snprintf(xdp_filename, sizeof(xdp_filename), "xdp_kern.o");
	load_xdp_program(ifindex, xdp_filename, &xdp_object);
	enter_xsks_into_map(ixsk, q, xdp_object);

#define RX_BATCH_SIZE      64
	uint32_t idx_rx;
	struct pollfd fds;
	for (;;) {

		D(printf("Poll enter...\n"));
		memset(&fds, 0, sizeof(fds));
		fds.fd = xsk_socket__fd(ixsk);
		fds.events = POLLIN;
		rc = poll(&fds, 1, -1);
		if (rc <= 0 || rc > 1)
			continue;
		D(printf("Poll returned %d\n", rc));

		idx_rx = 0;
		rc = xsk_ring_cons__peek(&rx, RX_BATCH_SIZE, &idx_rx);
		if (rc == 0)
			continue;
		D(printf("Received packets %d\n", rc));

		// Reserve space in the UMEM fill-queue to return the rexeived
		// buffers
		uint32_t idx;
		if (xsk_ring_prod__reserve(&uinfo->fq, rc, &idx) != rc)
			die("Failed xsk_ring_prod__reserve items=%d\n", rc);

		for (int i = 0; i < rc; i++, idx_rx++) {
			/* // Rx/Tx descriptor
			   struct xdp_desc {
			     __u64 addr;
				 __u32 len;
				 __u32 options;
			   };
			*/
			struct xdp_desc const* d = xsk_ring_cons__rx_desc(&rx, idx_rx);
			D(printf("Packet received %d\n", d->len));
			if (d->len < ETH_HLEN) {
				printf("Short frame %d\n", d->len);
				continue;
			}
			uint8_t *pkt = xsk_umem__get_data(uinfo->buffer, d->addr);
			Dx(printf(
				   " addr=%llu, pkt=%p, buffer=%p (%p)\n",
				   d->addr, pkt, uinfo->buffer, uinfo->buffer+d->addr));
			struct ethhdr* h = (struct ethhdr*)pkt;
			printf(
				"Received packet; len=%d, proto 0x%04x\n",
				d->len, ntohs(h->h_proto));
			D(printf(
				  "UMEM fq; %u\n", xsk_prod_nb_free(&uinfo->fq, 0)));
			*xsk_ring_prod__fill_addr(&uinfo->fq, idx++) = d->addr;
		}

		// Release the buffers from the xsk RX queue
		xsk_ring_cons__release(&rx, rc);
		// And (re)add them to the UMEM fill queue
		xsk_ring_prod__submit(&uinfo->fq, rc);
	}
	
	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCommand(void) {
	addCmd("receive", cmdReceive);
}
