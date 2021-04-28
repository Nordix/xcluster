/* SPDX-License-Identifier: GPL-2.0 */
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <netinet/in.h>
#include <linux/if_ether.h>
#include <linux/ipv6.h>
#include <linux/ip.h>
#include <bpf/bpf_endian.h>

// Map of VIP address. The XDP action should be the value.
struct bpf_map_def SEC("maps") xdp_vip_map = {
	.type        = BPF_MAP_TYPE_HASH,
	.value_size  = sizeof(int),
	.key_size    = sizeof(struct in6_addr),
	.max_entries = 4,
};

// Socket map for redirect to user-space
struct bpf_map_def SEC("maps") xsks_map = {
	.type = BPF_MAP_TYPE_XSKMAP,
	.key_size = sizeof(int),
	.value_size = sizeof(int),
	.max_entries = 4,			/* Must match nqueues for the nic */
};

/* Header cursor to keep track of current parsing position */
struct hdr_cursor {
        void *pos;
};

// Parsing functions copied from or "inspired by";
//  https://github.com/xdp-project/xdp-tutorial/tree/master/packet01-parsing

static __always_inline int parse_ethhdr(
	struct hdr_cursor *nh, void *data_end)
{
	struct ethhdr *eth = nh->pos;
	nh->pos += sizeof(*eth);

	/* Byte-count bounds check; check if current pointer + size of header
	 * is after data_end.
	 */
	if (nh->pos + 1 > data_end)
		return -1;

	return eth->h_proto; /* network-byte-order */
}

static __always_inline int parse_ip6hdr(
	struct hdr_cursor *nh, void *data_end, struct in6_addr* key)
{
	struct ipv6hdr* h = nh->pos;
	nh->pos += sizeof(*h);
	if (nh->pos + 1 > data_end)
		return -1;
	*key = h->daddr;
	return 0;
}

static __always_inline int parse_ip4hdr(
	struct hdr_cursor *nh, void *data_end, struct in6_addr* key)
{
	struct iphdr* h = nh->pos;
	nh->pos += sizeof(*h);
	if (nh->pos + 1 > data_end)
		return -1;
	key->s6_addr32[0] = 0;
	key->s6_addr32[1] = 0;
	key->s6_addr32[2] = bpf_htonl(0xffff);
	key->s6_addr32[3] = h->daddr;
	return 0;
}

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

SEC("xdp_vip")
int  xdp_filter_vip(struct xdp_md *ctx)
{
	void *data_end = (void*)(long)ctx->data_end;
	void *data = (void*)(long)ctx->data;
    int index = ctx->rx_queue_index;
	Dx("xdp_filter_vip %ld, Q %d", data_end - data, index);
	
	// Extract the destination IP address and create a hash map key.
	struct in6_addr key;
	struct hdr_cursor nh;
	nh.pos = data;
	int nh_type = parse_ethhdr(&nh, data_end);
	if (nh_type == bpf_htons(ETH_P_IPV6)) {
		if (parse_ip6hdr(&nh, data_end, &key) != 0)
			return XDP_ABORTED;
	} else if (nh_type == bpf_htons(ETH_P_IP)) {
		if (parse_ip4hdr(&nh, data_end, &key) != 0)
			return XDP_ABORTED;		
	} else {
		// Not IP
		return XDP_PASS;
	}

	D("  key %lx %lx", ntohl(key.s6_addr32[2]), ntohl(key.s6_addr32[3]));
	int* value = bpf_map_lookup_elem(&xdp_vip_map, &key);
	if (value != 0) {
		Dx("  VIP address");
		if (bpf_map_lookup_elem(&xsks_map, &index)) {
			int rc = bpf_redirect_map(&xsks_map, index, XDP_DROP);
			Dx("  Redirect to user-space, rc = %d", rc);
			return rc;
		}
		return *value;
	}

	return XDP_PASS;
}

// This program shall be attached to the interface connected to the
// real servers just to allow a AF_XDP socket for sending messages.
SEC("xdp_pass")
int  xdp_prog_pass(struct xdp_md *ctx)
{
	return XDP_PASS;
}

char _license[] SEC("license") = "GPL";

/* Copied from: $KERNEL/include/uapi/linux/bpf.h
 *
 * User return codes for XDP prog type.
 * A valid XDP program must return one of these defined values. All other
 * return codes are reserved for future use. Unknown return codes will
 * result in packet drops and a warning via bpf_warn_invalid_xdp_action().
 *
enum xdp_action {
	XDP_ABORTED = 0,
	XDP_DROP,
	XDP_PASS,
	XDP_TX,
	XDP_REDIRECT,
};

 * user accessible metadata for XDP packet hook
 * new fields must be added to the end of this structure
 *
struct xdp_md {
	// (Note: type __u32 is NOT the real-type)
	__u32 data;
	__u32 data_end;
	__u32 data_meta;
	// Below access go through struct xdp_rxq_info
	__u32 ingress_ifindex; // rxq->dev->ifindex
	__u32 rx_queue_index;  // rxq->queue_index
};
*/
