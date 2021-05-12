/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "maglev.h"
#include <stdint.h>
#include <getopt.h>
#include <fcntl.h>
#include <unistd.h>
#include <netinet/in.h>

// addCmd should be defined in main.c
void addCmd(char const* name, int (*fn)(int argc, char* argv[]));

void die(char const* fmt, ...)__attribute__ ((__noreturn__));

struct Option {
	char const* const name;
	char const** arg;
#define REQUIRED 1
#define OPTIONAL 0
	int required;
	char const* const help;
};
// Returns number of handled items, < 0 on error, 0 on help
int parseOptions(int argc, char* argv[], struct Option const* options);
int parseOptionsOrDie(int argc, char* argv[], struct Option const* options);

// Hash
struct ip6_hdr;
struct icmp6_hdr;
struct ctStats;
uint32_t djb2_hash(uint8_t const* c, uint32_t len);
unsigned ipv4Hash(unsigned len, uint8_t const* pkt);
unsigned ipv4TcpUdpHash(void const* data, unsigned len);
unsigned ipv4IcmpHash(void const* data, unsigned len);
unsigned ipv6Hash(void const* data, unsigned len);
unsigned ipv6AddressHash(void const* data, unsigned len);
int ipv6HandleFragment(void const* data, unsigned len, unsigned* hash);
struct ctStats const* ipv6FragStats(void);

// MAC
int macParse(char const* str, uint8_t* mac);
void macParseOrDie(char const* str, uint8_t* mac);
char const* macToString(uint8_t const* mac);
int getMAC(char const* iface, /*out*/ unsigned char* mac);

// Shared-mem
int createSharedData(char const* name, void* data, size_t len);
void createSharedDataOrDie(char const* name, void* data, size_t len);
void* mapSharedData(char const* name, size_t len, int mode);
void* mapSharedDataOrDie(char const* name, size_t len, int mode);

// Maglev
void maglevInit(struct MagData* m);
void maglevSetActive(struct MagData* m, unsigned v, int argc, char *argv[]);

// Print
void ipv4Print(unsigned len, uint8_t const* pkt);
void ipv6Print(unsigned len, uint8_t const* pkt);
void framePrint(unsigned len, uint8_t const* pkt);

// Csum (only ipv4 for now)
void tcpCsum(uint8_t* pkt, unsigned len);

// Conntrack
#define BUCKET_ALLOC() calloc(1,sizeof(struct ctBucket))
#define BUCKET_FREE(x) free(x)
typedef uint32_t ctCounter;
struct ctKey {
	struct in6_addr dst;
	struct in6_addr src;
	uint64_t fragid;
	// (fragid can be a union with {proto,dport,sport} for "real" ct)
};
struct ctStats {
	ctCounter size;
	ctCounter active;
	ctCounter collisions;
};
typedef void (*ctFree)(void* data);
struct ct* ctCreate(ctCounter hsize, uint64_t ttlNanos, ctFree freefn);
void* ctLookup(
	struct ct* ct, struct timespec* now, struct ctKey const* key);
// Return;
//  0 - Inserted, ctFree will be called.
//  1 - Updated, ctFree will be called for the updated data only.
// -1 - Failed, ctFree WILL NOT be called.
int ctInsert(
	struct ct* ct, struct timespec* now, struct ctKey const* key, void* data);
void ctRemove(
	struct ct* ct, struct timespec* now, struct ctKey const* key);
struct ctStats const* ctStats(
	struct ct* ct, struct timespec* now);
void ctDestroy(struct ct* ct);
