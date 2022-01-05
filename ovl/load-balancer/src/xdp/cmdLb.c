/* 
   SPDX-License-Identifier: MIT
   Copyright (c) Nordix Foundation
*/

#include "shm.h"
#include <util.h>
#include <die.h>
#include <cmd.h>
#include <shmem.h>
#include <iputils.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
#include <bpf/xsk.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <unistd.h>

#define D(x)
#define Dx(x) x

// Forward declaration;
static uint8_t const*
getDestMAC(struct SharedData* sh, uint8_t const* pkt, unsigned len);

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
	xsk_cfg.bind_flags = XDP_COPY; /* (XDP_SHARED_UMEM is added in the call) */
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
	char const* shmName = defaultShmName;
	char const* idev;
	char const* edev;
	char const* queue = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "lb [options]\n"
		 "  Start load-balancing in user-space"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{"idev", &idev, REQUIRED, "Ingress device"},
		{"edev", &edev, REQUIRED, "Egress device"},
		{"queue", &queue, 0, "The RX queue to use. Default 0"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1)
		return EXIT_FAILURE;
	argc -= nopt;
	argv += nopt;
	struct SharedData* sh = mapSharedDataOrDie(shmName, O_RDONLY);
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
	struct xsk_info* ixinfo = create_xsk_info(idev, q, uinfo, 1024);
	/*
	  PROBLEM; q=0 can't be used for the xsk to the egress interface
	  since it seem to clash with q=0 on the *ingress*
	  interface. Traffic is not received. Q is hard-coded to 1 as a
	  work-around. This requires the egress interface to have >1
	  queue.
	 */
	struct xsk_info* exinfo = create_xsk_info(edev, 1, uinfo, 0);

#define RX_BATCH_SIZE      64
	uint32_t idx_rx;
	struct pollfd fds;
	int nreceived;
	for (;;) {

		D(printf("Poll enter...\n"));
		memset(&fds, 0, sizeof(fds));
		fds.fd = xsk_socket__fd(ixinfo->xsk);
		fds.events = POLLIN;
		rc = poll(&fds, 1, -1);
		if (rc < 0)
			die("poll %s\n", strerror(-rc));
		if (rc == 0)
			continue;
		D(printf("Poll returned %d\n", rc));

		idx_rx = 0;
		nreceived = xsk_ring_cons__peek(&ixinfo->rx, RX_BATCH_SIZE, &idx_rx);
		if (nreceived == 0)
			continue;
		D(printf("Received packets %d\n", nreceived));

		uint32_t tx_idx = 0;
		rc = xsk_ring_prod__reserve(&exinfo->tx, nreceived, &tx_idx);
		if (rc != nreceived)
			die("Can't reserve transmit slot %d\n", rc);

		for (int i = 0; i < nreceived; i++, idx_rx++, tx_idx++) {
			struct xdp_desc const* d = xsk_ring_cons__rx_desc(&ixinfo->rx, idx_rx);
			uint8_t *pkt = xsk_umem__get_data(uinfo->buffer, d->addr);
			D(framePrint(d->len, pkt));
			struct ethhdr* h = (struct ethhdr*)pkt;
			memcpy(h->h_source, emac, ETH_ALEN);
			memcpy(h->h_dest, getDestMAC(sh, pkt, d->len), ETH_ALEN);
			tcpCsum(pkt, d->len);

			// Enqueue packet on the egress device.
			// We transfer the buffer (without copy) to the tx queue.
			struct xdp_desc* td;
			td = xsk_ring_prod__tx_desc(&exinfo->tx, tx_idx);
			td->addr = d->addr;
			td->len = d->len;
		}

		xsk_ring_prod__submit(&exinfo->tx, nreceived);
		rc = sendto(
			xsk_socket__fd(exinfo->xsk), NULL, 0, MSG_DONTWAIT,NULL, 0);
		D(printf("Sendto %d\n", rc));
		xsk_ring_cons__release(&ixinfo->rx, nreceived);

		// Now we must take care of buffers used in previous sends now
		// returned to us in the completed queue. The buffers should
		// be consumed from the completed queue of the egress device
		// and (re)inserted in the fill queue of the ingress device.

		uint32_t idx_cq = 0;
		unsigned completed = xsk_ring_cons__peek(&exinfo->cq, RX_BATCH_SIZE, &idx_cq);
		D(printf("Reclaiming %u completed buffers\n", completed));
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
__attribute__ ((__constructor__)) static void addCommand(void) {
	addCmd("lb", cmdLb);
}

static uint8_t const*
getDestMAC(struct SharedData* sh, uint8_t const* pkt, unsigned len)
{
	unsigned hash = 0;
	if (len > ETH_HLEN) {
		struct ethhdr* h = (struct ethhdr*)pkt;
		if (ntohs(h->h_proto) == ETH_P_IP) {
			struct ctKey key = {0};
			if (getHashKey(&key, 0, NULL, ETH_P_IP, pkt + ETH_HLEN, len - ETH_HLEN) >= 0)
				hash = hashKey(&key);
			//hash = ipv4Hash(len - ETH_HLEN, pkt + ETH_HLEN);
		}
	}
	unsigned t = sh->m.lookup[hash % sh->m.M];
	D(printf("Load-balance to (%u); %u, %s\n", hash % sh->m.M, t, macToString(sh->target[t])));
	return sh->target[t];
}

