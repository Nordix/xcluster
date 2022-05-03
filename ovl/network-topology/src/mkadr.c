#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>

static void die(char const* fmt, ...)__attribute__ ((__noreturn__));
static void die(char const* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	exit(EXIT_FAILURE);
}

static void help(void)__attribute__ ((__noreturn__));
static void help(void)
{
	char const* const helpTxt =
		"\n"
		"Syntax:\n"
		"  mkadr template net host\n"
		"\n"
		"'template' is a cidr address with double slashes for net and\n"
		"host masks. Example;\n"
		"\n"
		"  192.168.128/17/24\n"
		"  1000:2000:3000::3:0/112/120\n"
		"\n"
		"The address is formed by inserting 'net' and 'host' in the\n"
		"bit-fields. Example\n"
		"\n"
		"  # mkadr 192.168.128.0/17/24 3 12\n"
		"  192.168.131.12\n"
		"  # mkadr 1000::192.168.0.0/112/120 3 1\n"
		"  1000::c0a8:301\n";
	puts(helpTxt);
	exit(EXIT_SUCCESS);
}

static void ipv4(char const* adr, int nmask, int hmask, int n, int h);
static void ipv6(char const* adr, int nmask, int hmask, int n, int h);

int
main(int argc, char* argv[])
{
	if (argc < 2)
		help();
	if (argc < 4)
		die("To few arguments\n");

	
	int nmask, hmask, n, h;
	char const* adr = strtok(argv[1], "/");
	char* cp = strtok(NULL, "/");
	if (cp == NULL)
		die("Invalid template\n");
	nmask = atoi(cp);
	cp = strtok(NULL, "/");
	if (cp == NULL)
		die("Invalid template\n");
	hmask = atoi(cp);
	if (nmask > hmask)
		die("Net-mask larger than host-mask\n");
	if (nmask < 1)
		die("Net-mask and host-mask must be > 0\n");
	n = atoi(argv[2]);
	h = atoi(argv[3]);
	if (n < 0 || h < 0)
		die("Negative values\n");
	//printf("# %s %d %d %d %d\n", adr, nmask, hmask, n, h);

	if (strchr(adr, ':') != NULL)
		ipv6(adr, nmask, hmask, n, h);
	else
		ipv4(adr, nmask, hmask, n, h);
	
	return 0;
}

static void ipv4(char const* adr, int nmask, int hmask, int n, int h)
{
	struct in_addr addr;
	if (inet_pton(AF_INET, adr, &addr) != 1)
		die("Invalid address [%s]\n", adr);

	if (nmask <= 1)
		die("Net-mask must be > 1\n");
	if (hmask >= 32)
		die("Host-mask must be < 32\n");

	int hmax = (1 << (32-hmask)) - 1;
	if (h > hmax)
		die("Host too large [%d]\n", h);
	int nmax = (1 << (hmask - nmask)) - 1;
	if (n > nmax)
		die("Net too large [%d]\n", n);

	uint32_t a = ntohl(addr.s_addr);
	a &= ~((1 << (32 - nmask)) - 1);
	a += n << (32 - hmask);
	a += h;
	addr.s_addr = htonl(a);

	char strbuf[INET6_ADDRSTRLEN+1];
	inet_ntop(AF_INET, &addr, strbuf, sizeof(strbuf));
	puts(strbuf);
}

static void mask_ipv6(struct in6_addr* a, unsigned prefix);

static void ipv6(char const* adr, int nmask, int hmask, int n, int h)
{
	struct in6_addr a6;
	if (inet_pton(AF_INET6, adr, &a6) != 1)
		die("Invalid address [%s]\n", adr);

	if (nmask <= 64)
		die("Net-mask must be > 64\n");
	if (hmask >= 128)
		die("Host-mask must be < 128\n");
	mask_ipv6(&a6, nmask);

	uint64_t* p = (uint64_t*)(a6.s6_addr32 + 2);
	uint64_t a = be64toh(*p);
	a += n << (128 - hmask);
	a += h;
	*p = htobe64(a);

	char strbuf[INET6_ADDRSTRLEN+1];
	inet_ntop(AF_INET6, &a6, strbuf, sizeof(strbuf));
	puts(strbuf);
}

static void mask_ipv6(struct in6_addr* a, unsigned prefix)
{
	unsigned bits_to_clear = 128 - prefix;
	unsigned i = 3;
	while (bits_to_clear >= 32) {
		a->s6_addr32[i] = 0;
		bits_to_clear -= 32;
		i--;
	}
	if (bits_to_clear == 0)
		return;
	uint32_t mask = htonl(~((1 << bits_to_clear) - 1));
	a->s6_addr32[i] &= mask;
}
