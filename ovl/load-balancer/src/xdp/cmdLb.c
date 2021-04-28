/* 
   SPDX-License-Identifier: MIT
   Copyright (c) Nordix Foundation
*/

#include <util.h>
#include <stdlib.h>
//#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
//#include <bpf/libbpf.h>
//#include <bpf/bpf.h>
#include <bpf/xsk.h>
#include <net/if.h>
#include <linux/if_ether.h>

#define D(x)
#define Dx(x) x

// Forward declaration;
static int getDestMAC(struct xdp_desc const* d, unsigned char* dmac);

// This struct is used in xdp-tutorial and kernel sample
struct xsk_umem_info {
	struct xsk_ring_prod fq;
	struct xsk_ring_cons cq;
	struct xsk_umem *umem;
	void *buffer;
	unsigned nframes;
	unsigned framesize;
	unsigned nallocated;
};
/*
  UMEM will be shared and must be used both for rx and tx.
  By default 2048 frames are allocated
  https://www.kernel.org/doc/html/latest/networking/af_xdp.html#xdp-shared-umem-bind-flag
 */
static struct xsk_umem_info* create_umem(unsigned nfq)
{
	struct xsk_umem_info* u;
	u = calloc(1, sizeof(*u));
	// XSK_RING_PROD__DEFAULT_NUM_DESCS=2048
	u->nframes = XSK_RING_PROD__DEFAULT_NUM_DESCS;
	u->framesize = XSK_UMEM__DEFAULT_FRAME_SIZE;
	
	uint64_t buffer_size = u->nframes * u->framesize;
	if (posix_memalign(&u->buffer, getpagesize(), buffer_size) != 0)
		die("Can't allocate buffer memory [%s]\n", strerror(errno));
	int rc = xsk_umem__create(
		&u->umem, u->buffer, buffer_size, &u->fq, &u->cq, NULL);
	if (rc != 0)
		die("Failed to create umem; %s\n", strerror(-rc));

	if (nfq > 0) {
		uint32_t idx;
		rc = xsk_ring_prod__reserve(&u->fq, nfq, &idx);
		if (rc != nfq)
			die("Failed xsk_ring_prod__reserve; %s\n", strerror(-rc));

		int i;
		for (i = 0; i < nfq; i++, idx++) {
			*xsk_ring_prod__fill_addr(&u->fq, idx) = i * u->framesize;
		}
		xsk_ring_prod__submit(&u->fq, nfq);
		u->nallocated = nfq;
	}
	return u;
}

// Holds data for a xsk_socket that uses shared UMEM
struct xsk_info {
	struct xsk_socket* xsk;
	struct xsk_ring_cons rx;
	struct xsk_ring_prod tx;
	struct xsk_ring_prod fq;
	struct xsk_ring_cons cq;
};
// Open a xsk_socket.
// "nfq" is the number of buffers taken from "uinfo" and placed in the
// fill queue.
static struct xsk_info* create_xsk_info(
	char const* dev, int q, struct xsk_umem_info *u, unsigned nfq)
{
	// Check that the UMEM has enough free buffers
	if ((u->nallocated + nfq) > u->nframes)
		die("Umem exhausted\n");

	struct xsk_info* x = calloc(1, sizeof(*x));
	struct xsk_socket_config xsk_cfg;
	xsk_cfg.rx_size = XSK_RING_CONS__DEFAULT_NUM_DESCS;
	xsk_cfg.tx_size = XSK_RING_PROD__DEFAULT_NUM_DESCS;
	xsk_cfg.libbpf_flags = 0;
	xsk_cfg.xdp_flags = 0;
	xsk_cfg.bind_flags = 0;		/* (XDP_SHARED_UMEM is added in the call) */
	int rc = xsk_socket__create_shared(
		&x->xsk, dev, q, u->umem, &x->rx, &x->tx, &x->fq, &x->cq, &xsk_cfg);
	if (rc != 0)
		die("Failed xsk_socket__create shared %s; %s\n", dev, strerror(-rc));

	if (nfq > 0) {
		uint32_t idx;
		rc = xsk_ring_prod__reserve(&x->fq, nfq, &idx);
		if (rc != nfq)
			die("Failed xsk_ring_prod__reserve; %s\n", strerror(-rc));

		int i = u->nallocated;
		u->nallocated += nfq;
		for (i = 0; i < u->nallocated; i++, idx++) {
			*xsk_ring_prod__fill_addr(&x->fq, idx) = i * u->framesize;
		}
		xsk_ring_prod__submit(&x->fq, nfq);
	}
	return x;
}


static int cmdLb(int argc, char **argv)
{
	char const* idev;
	char const* edev;
	char const* queue = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "lb [options]\n"
		 "  Start load-balancing in user-space"},
		{"idev", &idev, REQUIRED,
		 "Ingress device"},
		{"edev", &edev, REQUIRED,
		 "Egress device"},
		{"queue", &queue, 0,
		 "The RX queue to use. Default 0"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1)
		return EXIT_FAILURE;
	argc -= nopt;
	argv += nopt;
	unsigned int iifindex = if_nametoindex(idev);
	if (iifindex == 0)
		die("Unknown interface [%s]\n", idev);
	unsigned int eifindex = if_nametoindex(edev);
	if (eifindex == 0)
		die("Unknown interface [%s]\n", edev);
	unsigned char emac[ETH_ALEN];
	if (getMAC(edev, emac) != 0)
		die("Could not get MAC for [%s]\n", edev);
	int q = 0;
	if (queue != NULL)
		q = atoi(queue);

	// (just checking?)
	uint32_t prog_id = 0;
	int rc;
	rc = bpf_get_link_xdp_id(iifindex, &prog_id, 0);
	if (rc != 0)
		die("Failed bpf_get_link_xdp_id ingress; %s\n", strerror(-rc));
	rc = bpf_get_link_xdp_id(eifindex, &prog_id, 0);
	if (rc != 0)
		die("Failed bpf_get_link_xdp_id egress; %s\n", strerror(-rc));

	struct xsk_umem_info* uinfo = create_umem(0);
	struct xsk_info* ixinfo = create_xsk_info(idev, q, uinfo, 512);
	struct xsk_info* exinfo = create_xsk_info(edev, q, uinfo, 0);

#define RX_BATCH_SIZE      64
	uint32_t idx_rx;
	struct pollfd fds;
	int nreceived;
	for (;;) {

		Dx(printf("Poll enter...\n"));
		memset(&fds, 0, sizeof(fds));
		fds.fd = xsk_socket__fd(ixinfo->xsk);
		fds.events = POLLIN;
		rc = poll(&fds, 1, -1);
		if (rc < 0)
			die("poll %s\n", strerror(-rc));
		if (rc == 0)
			continue;
		Dx(printf("Poll returned %d\n", rc));

		idx_rx = 0;
		nreceived = xsk_ring_cons__peek(&ixinfo->rx, RX_BATCH_SIZE, &idx_rx);
		if (nreceived == 0)
			continue;
		D(printf("Received packets %d\n", nreceived));

		for (int i = 0; i < rc; i++, idx_rx++) {
			/* // Rx/Tx descriptor
			   struct xdp_desc {
			     __u64 addr;
				 __u32 len;
				 __u32 options;
			   };
			*/
			struct xdp_desc const* d = xsk_ring_cons__rx_desc(&ixinfo->rx, idx_rx);
			D(printf("Packet received %d\n", d->len));
			if (d->len > ETH_HLEN) {
				uint8_t *pkt = xsk_umem__get_data(uinfo->buffer, d->addr);
				D(printf(
					   " addr=%llu, pkt=%p, buffer=%p (%p)\n",
					   d->addr, pkt, packet_buffer, packet_buffer+d->addr));
				struct ethhdr* h = (struct ethhdr*)pkt;
				memcpy(h->h_source, emac, ETH_ALEN);
				if (getDestMAC(d, h->h_dest) == 0) {
					Dx(framePrint(d->len, pkt));
					// Send packet on the egress device.
					// We transfer the buffer (without copy) to the tx queue
					// of the egress device.
					uint32_t tx_idx = 0;
					rc = xsk_ring_prod__reserve(&exinfo->tx, 1, &tx_idx);
					if (rc != 1)
						die("Can't reserve transmit slot %d\n", rc);
					Dx(printf("Reserved transmit slot %u\n", tx_idx));
					struct xdp_desc* td;
					td = xsk_ring_prod__tx_desc(&exinfo->tx, tx_idx);
					td->addr = d->addr;
					td->len = d->len;
					xsk_ring_prod__submit(&exinfo->tx, 1);
					rc = sendto(
						xsk_socket__fd(exinfo->xsk), NULL, 0, MSG_DONTWAIT, NULL, 0);
					Dx(printf("Sendto %d\n", rc));
				}
			}
		}
		xsk_ring_cons__release(&ixinfo->rx, nreceived);

		// Now we must take care of buffers used in previous sends now
		// returned to us in the completed queue. The buffers should
		// be consumed from the completed queue of the egress device
		// and (re)inserted in the fill queue of the ingress device.

		uint32_t idx_cq = 0;
		unsigned completed = xsk_ring_cons__peek(&exinfo->cq, RX_BATCH_SIZE, &idx_cq);
		Dx(printf("Reclaiming %u completed buffers\n", completed));
		if (completed > 0) {
			uint32_t idx_fq = 0;
			if (xsk_ring_prod__reserve(&ixinfo->fq, completed, &idx_fq) != completed)
				die("Failed to reserve completed=%u\n", completed);
			for (int i = 0; i < completed; i++, idx_fq++, idx_cq++) {
				xsk_ring_prod__tx_desc(&ixinfo->fq, idx_fq)->addr =
					xsk_ring_cons__rx_desc(&exinfo->cq, idx_cq)->addr;
			}
			xsk_ring_prod__submit(&ixinfo->fq, completed);
			xsk_ring_cons__release(&exinfo->cq, completed);
		}
	}

	
	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCmdFwd(void) {
	addCmd("lb", cmdLb);
}

static int getDestMAC(struct xdp_desc const* d, unsigned char* dmac)
{
	static uint8_t const vm1[ETH_ALEN] = {0,0,0,1,1,1};
	memcpy(dmac, vm1, ETH_ALEN);
	return 0;
}
