#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <arpa/inet.h>

#include <libmnl/libmnl.h>
#include <linux/netfilter.h>
#include <linux/netfilter/nfnetlink.h>

#include <linux/types.h>
#include <linux/netfilter/nfnetlink_queue.h>

#include <libnetfilter_queue/libnetfilter_queue.h>

/* only for NFQA_CT, not needed otherwise: */
#include <linux/netfilter/nfnetlink_conntrack.h>

static uint32_t (*get_mark)(uint32_t hash);
static void initHash(int argc, char* argv[]);
static int cmdCreate(int argc, char* argv[]);
static int cmdShow(int argc, char* argv[]);
static int cmdClean(int argc, char* argv[]);
static int cmdActivate(int argc, char* argv[]);
static int cmdDeactivate(int argc, char* argv[]);
static struct Cmd {
	char const* const name;
	int (*fn)(int argc, char* argv[]);
} cmd[] = {
	{"create", cmdCreate},
	{"show", cmdShow},
	{"clean", cmdClean},
	{"activate", cmdActivate},
	{"deactivate", cmdDeactivate},
	{"run", NULL}
};
static uint32_t
djb2_hash(uint8_t* c, uint32_t len)
{
	uint32_t hash = 5381;
	while (len--)
		hash = ((hash << 5) + hash) + *c++; /* hash * 33 + c */
	return hash;
}

static struct mnl_socket *nl;

static struct nlmsghdr *
nfq_hdr_put(char *buf, int type, uint32_t queue_num)
{
	struct nlmsghdr *nlh = mnl_nlmsg_put_header(buf);
	nlh->nlmsg_type	= (NFNL_SUBSYS_QUEUE << 8) | type;
	nlh->nlmsg_flags = NLM_F_REQUEST;

	struct nfgenmsg *nfg = mnl_nlmsg_put_extra_header(nlh, sizeof(*nfg));
	nfg->nfgen_family = AF_UNSPEC;
	nfg->version = NFNETLINK_V0;
	nfg->res_id = htons(queue_num);

	return nlh;
}

static void
nfq_send_verdict(int queue_num, uint32_t id, uint32_t mark)
{
	char buf[MNL_SOCKET_BUFFER_SIZE];
	struct nlmsghdr *nlh;
	struct nlattr *nest;

	nlh = nfq_hdr_put(buf, NFQNL_MSG_VERDICT, queue_num);
	nfq_nlmsg_verdict_put(nlh, id, NF_ACCEPT);
	nfq_nlmsg_verdict_put_mark(nlh, mark);

	/* example to set the connmark. First, start NFQA_CT section: */
	nest = mnl_attr_nest_start(nlh, NFQA_CT);

	/* then, add the connmark attribute: */
	mnl_attr_put_u32(nlh, CTA_MARK, htonl(42));
	/* more conntrack attributes, e.g. CTA_LABEL, could be set here */

	/* end conntrack section */
	mnl_attr_nest_end(nlh, nest);

	if (mnl_socket_sendto(nl, nlh, nlh->nlmsg_len) < 0) {
		perror("mnl_socket_send");
		exit(EXIT_FAILURE);
	}
}

static int queue_cb(const struct nlmsghdr *nlh, void *data)
{
	struct nfqnl_msg_packet_hdr *ph = NULL;
	struct nlattr *attr[NFQA_MAX+1] = {};
	uint32_t id = 0, skbinfo;
	struct nfgenmsg *nfg;
	uint16_t plen;

	if (nfq_nlmsg_parse(nlh, attr) < 0) {
		perror("problems parsing");
		return MNL_CB_ERROR;
	}

	nfg = mnl_nlmsg_get_payload(nlh);

	if (attr[NFQA_PACKET_HDR] == NULL) {
		fputs("metaheader not set\n", stderr);
		return MNL_CB_ERROR;
	}

	ph = mnl_attr_get_payload(attr[NFQA_PACKET_HDR]);

	plen = mnl_attr_get_payload_len(attr[NFQA_PAYLOAD]);
	id = ntohl(ph->packet_id);

	/*
	  Addresses;
	  ipv4; payload[12], len 8
	  ipv6; payload[8], len 32
	  TODO; For ICMP "packet too big" compute hash for the "inner" address.
	 */
	uint8_t *payload = mnl_attr_get_payload(attr[NFQA_PAYLOAD]);
	uint32_t hash;
	if (ntohs(ph->hw_protocol) == 0x0800) {
		hash = djb2_hash(payload + 12, 8);
	} else if (ntohs(ph->hw_protocol) == 0x86dd) {
		hash = djb2_hash(payload + 8, 32);
	}
	
#if 0
	printf("packet received id=%u hw=0x%04x payload len %u, mark=%u\n",
		id, ntohs(ph->hw_protocol), plen, mark);
#endif
	nfq_send_verdict(ntohs(nfg->res_id), id, get_mark(hash));

	return MNL_CB_OK;
}

static int config(int argc, char *argv[]);

int main(int argc, char *argv[])
{
	char *buf;
	/* largest possible packet payload, plus netlink data overhead: */
	size_t sizeof_buf = 0xffff + (MNL_SOCKET_BUFFER_SIZE/2);
	struct nlmsghdr *nlh;
	int ret;
	unsigned int portid, queue_num = 2;

	if (argc < 2) {
		printf("Usage: %s <command> [opt...]\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	for (struct Cmd* c = cmd; c->fn != NULL; c++) {
		if (strcmp(argv[1], c->name) == 0)
			return c->fn(argc - 2, argv + 2);
	}

	if (argc > 2) queue_num = atoi(argv[2]);
	initHash(argc - 2, argv + 2);

	nl = mnl_socket_open(NETLINK_NETFILTER);
	if (nl == NULL) {
		perror("mnl_socket_open");
		exit(EXIT_FAILURE);
	}

	if (mnl_socket_bind(nl, 0, MNL_SOCKET_AUTOPID) < 0) {
		perror("mnl_socket_bind");
		exit(EXIT_FAILURE);
	}
	portid = mnl_socket_get_portid(nl);

	buf = malloc(sizeof_buf);
	if (!buf) {
		perror("allocate receive buffer");
		exit(EXIT_FAILURE);
	}

	/* PF_(UN)BIND is not needed with kernels 3.8 and later */
	nlh = nfq_hdr_put(buf, NFQNL_MSG_CONFIG, 0);
	nfq_nlmsg_cfg_put_cmd(nlh, AF_INET, NFQNL_CFG_CMD_PF_UNBIND);

	if (mnl_socket_sendto(nl, nlh, nlh->nlmsg_len) < 0) {
		perror("mnl_socket_send");
		exit(EXIT_FAILURE);
	}

	nlh = nfq_hdr_put(buf, NFQNL_MSG_CONFIG, 0);
	nfq_nlmsg_cfg_put_cmd(nlh, AF_INET, NFQNL_CFG_CMD_PF_BIND);

	if (mnl_socket_sendto(nl, nlh, nlh->nlmsg_len) < 0) {
		perror("mnl_socket_send");
		exit(EXIT_FAILURE);
	}

	nlh = nfq_hdr_put(buf, NFQNL_MSG_CONFIG, queue_num);
	nfq_nlmsg_cfg_put_cmd(nlh, AF_INET, NFQNL_CFG_CMD_BIND);

	if (mnl_socket_sendto(nl, nlh, nlh->nlmsg_len) < 0) {
		perror("mnl_socket_send");
		exit(EXIT_FAILURE);
	}

	nlh = nfq_hdr_put(buf, NFQNL_MSG_CONFIG, queue_num);
	nfq_nlmsg_cfg_put_params(nlh, NFQNL_COPY_PACKET, 0xffff);

	mnl_attr_put_u32(nlh, NFQA_CFG_FLAGS, htonl(NFQA_CFG_F_GSO));
	mnl_attr_put_u32(nlh, NFQA_CFG_MASK, htonl(NFQA_CFG_F_GSO));

	if (mnl_socket_sendto(nl, nlh, nlh->nlmsg_len) < 0) {
		perror("mnl_socket_send");
		exit(EXIT_FAILURE);
	}

	/* ENOBUFS is signalled to userspace when packets were lost
	 * on kernel side.  In most cases, userspace isn't interested
	 * in this information, so turn it off.
	 */
	ret = 1;
	mnl_socket_setsockopt(nl, NETLINK_NO_ENOBUFS, &ret, sizeof(int));

	for (;;) {
		ret = mnl_socket_recvfrom(nl, buf, sizeof_buf);
		if (ret == -1) {
			perror("mnl_socket_recvfrom");
			exit(EXIT_FAILURE);
		}

		ret = mnl_cb_run(buf, ret, 0, portid, queue_cb, NULL);
		if (ret < 0){
			perror("mnl_cb_run");
			exit(EXIT_FAILURE);
		}
	}

	mnl_socket_close(nl);

	return 0;
}

/* ---------------------------------------------------------------------- */
#include "maglev.h"
#include <sys/mman.h>
#include <fcntl.h>

static void die(char const* msg)
{
	perror(msg);
	exit(EXIT_FAILURE);
}

static struct MagData* magd;
static uint32_t get_maglev_mark(uint32_t hash)
{
	return magd->lookup[hash % magd->M] + 1;
}

static void initHash(int argc, char* argv[])
{
	int fd = shm_open("maglev", O_RDONLY, 0400);
	if (fd < 0) die("shm_open");
	magd = mmap(
		NULL, sizeof(struct MagData), PROT_READ, MAP_SHARED, fd, 0);
	if (magd == MAP_FAILED) die("mmap");
	get_mark = get_maglev_mark;
}

static struct MagData* mapMagData(int mode)
{
	int fd = shm_open("maglev", mode, (mode == O_RDONLY)?0400:0600);
	if (fd < 0) die("shm_open");
	struct MagData* m = mmap(
		NULL, sizeof(struct MagData),
		(mode == O_RDONLY)?PROT_READ:PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	if (m == MAP_FAILED) die("mmap");
	return m;
}

static int cmdCreate(int argc, char* argv[])
{
	int fd = shm_open("maglev", O_RDWR|O_CREAT, 0600);
	if (fd < 0) die("shm_open");
	struct MagData m;
	initMagData(&m, 997, 10);
	for (int i = 0; i < 4; i++)
		m.active[i] = 1;
	populate(&m);
	write(fd, &m, sizeof(m));
	return 0;
}
static int cmdShow(int argc, char* argv[])
{
	struct MagData* m = mapMagData(O_RDONLY);
	printf("M=%u, N=%u\n", m->M, m->N);
	printf("Active;\n");
	for (int i = 0; i < m->N; i++)
		printf(" %u", m->active[i]);
	puts("");
	printf("Lookup;\n");
	for (int i = 0; i < 25; i++)
		printf(" %d", m->lookup[i]);
	puts(" ...");
	return 0;
}
static int cmdClean(int argc, char* argv[])
{
	if (shm_unlink("maglev") != 0) die("shm_unlink");
	return 0;
}

static void setActivate(unsigned v, int argc, char *argv[])
{
	struct MagData* m = mapMagData(O_RDWR);
	while (argc-- > 0) {
		int i = atoi(*argv++) - 1;
		if (i >= 0 && i < m->N) m->active[i] = v;
	}
	printf("Active;\n");
	for (int i = 0; i < m->N; i++)
		printf(" %u", m->active[i]);
	puts("");
	populate(m);
}
static int cmdActivate(int argc, char* argv[])
{
	setActivate(1, argc, argv);
	return 0;
}
static int cmdDeactivate(int argc, char* argv[])
{
	setActivate(0, argc, argv);
	return 0;
}


