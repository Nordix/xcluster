// From;
// https://gist.github.com/david-hoze/0c7021434796997a4ca42d7731a7073a

#include <netinet/tcp.h>
#include <netinet/ip.h>
//#include <net/if.h>
#include <linux/if_ether.h>

/* set tcp checksum: given IP header and tcp segment */
static void compute_tcp_checksum(struct iphdr *pIph, unsigned short *ipPayload) {
	register unsigned long sum = 0;
	unsigned short tcpLen = ntohs(pIph->tot_len) - (pIph->ihl<<2);
	struct tcphdr *tcphdrp = (struct tcphdr*)(ipPayload);
	//add the pseudo header 
	//the source ip
	sum += (pIph->saddr>>16)&0xFFFF;
	sum += (pIph->saddr)&0xFFFF;
	//the dest ip
	sum += (pIph->daddr>>16)&0xFFFF;
	sum += (pIph->daddr)&0xFFFF;
	//protocol and reserved: 6
	sum += htons(IPPROTO_TCP);
	//the length
	sum += htons(tcpLen);
 
	//add the IP payload
	//initialize checksum to 0
	tcphdrp->check = 0;
	while (tcpLen > 1) {
		sum += * ipPayload++;
		tcpLen -= 2;
	}
	//if any bytes left, pad the bytes and add
	if(tcpLen > 0) {
		//printf("+++++++++++padding, %dn", tcpLen);
		sum += ((*ipPayload)&htons(0xFF00));
	}
	//Fold 32-bit sum to 16 bits: add carrier to result
	while (sum>>16) {
		sum = (sum & 0xffff) + (sum >> 16);
	}
	sum = ~sum;
	//set computation result
	tcphdrp->check = (unsigned short)sum;
}

void tcpCsum(uint8_t* pkt, unsigned len)
{
	if (len < ETH_HLEN)
		return;
	struct ethhdr* h = (struct ethhdr*)pkt;
	if (ntohs(h->h_proto) != ETH_P_IP)
		return;
	pkt += ETH_HLEN;
	len -= ETH_HLEN;
	if (len < sizeof(struct iphdr))
		return;
	struct iphdr* ih = (struct iphdr*)pkt;
	if (ih->protocol != IPPROTO_TCP)
		return;
	unsigned iphlen = ih->ihl * 4;
	if (len < iphlen)
		return;
	pkt += iphlen;
	len -= iphlen;
	if (len < sizeof(struct tcphdr))
		return;
	compute_tcp_checksum(ih, (unsigned short*)pkt);
}
