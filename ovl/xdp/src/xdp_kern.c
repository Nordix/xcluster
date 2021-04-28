/* SPDX-License-Identifier: GPL-2.0 */
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <linux/if_ether.h>
#include <bpf/bpf_endian.h>

// Socket map for redirect to user-space
struct bpf_map_def SEC("maps") xsks_map = {
	.type = BPF_MAP_TYPE_XSKMAP,
	.key_size = sizeof(int),
	.value_size = sizeof(int),
	.max_entries = 4,			/* Must be > nqueues for the nic */
};


#if 1
#define Dx(fmt, ...)                                      \
    ({                                                         \
        char ____fmt[] = fmt;                                  \
        bpf_trace_printk(____fmt, sizeof(____fmt), ##__VA_ARGS__); \
    })
#else
#define Dx(fmt, ...)
#endif
#define D(fmt, ...)

SEC("xdp_redirect")
int  xdp_prog_redirect(struct xdp_md *ctx)
{
	void *data_end = (void*)(long)ctx->data_end;
	void *data = (void*)(long)ctx->data;
	/*
	  We redirect only IPv4 packets so other funtions (e.g. ARP) works.
	 */
	long len = data_end - data;
	D("Received len = %ld", len);

#if 0
	// Why does this not work?? (bpf validation fails!)
	if (len + 1 <= sizeof(struct ethhdr))
		return XDP_ABORTED;
#endif

	void *pos = data;
	struct ethhdr const* h = (struct ethhdr const*)pos;
	pos += sizeof(struct ethhdr);
	if (pos + 1 > data_end)
		return XDP_ABORTED;		/* (short frame) */

	if (h->h_proto != bpf_htons(ETH_P_IP))
		return XDP_PASS;		/* Not IPv4 */

	int index = ctx->rx_queue_index;
	int rc = bpf_redirect_map(&xsks_map, index, XDP_PASS);
	Dx("Received %ld, Q %d,  redirect, rc = %d", len, index, rc);
	return rc;
}

SEC("xdp_pass")
int  xdp_prog_pass(struct xdp_md *ctx)
{
	return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
