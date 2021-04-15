/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/
#include "util.h"
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <string.h>
#include <errno.h>

void die(char const* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	exit(EXIT_FAILURE);
}

uint32_t djb2_hash(uint8_t const* c, uint32_t len)
{
	uint32_t hash = 5381;
	while (len--)
		hash = ((hash << 5) + hash) + *c++; /* hash * 33 + c */
	return hash;
}

int macParse(char const* str, uint8_t* mac)
{
	int values[6];
	int i = sscanf(
		str, "%x:%x:%x:%x:%x:%x%*c",
		&values[0], &values[1], &values[2],
		&values[3], &values[4], &values[5]);

	if (i == 6) {
		/* convert to uint8_t */
		for( i = 0; i < 6; ++i )
			mac[i] = (uint8_t) values[i];
		return 0;
	}
    /* invalid mac */
	return -1;
}
void macParseOrDie(char const* str, uint8_t* mac)
{
	if (macParse(str, mac) != 0)
		die("Parse MAC failed [%s]\n", str);
}

char const* macToString(uint8_t const* mac)
{
#define MAX_MACBUF 2
	static char buf[MAX_MACBUF][20];
	static int bindex = 0;
	if (bindex++ == MAX_MACBUF) bindex = 0;
	sprintf(
		buf[bindex], "%02x:%02x:%02x:%02x:%02x:%02x",
		mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
	return buf[bindex];
}

void verifyRequiredOptions(
	struct option const* long_options, unsigned required, unsigned got)
{
	got = got & required;
	if (required == got) return;
	unsigned i, m;
	for (i = 0; i < 32; i++) {
		m = (1 << i);
		if ((required & m) != (got & m)) {
			char const* opt = "(unknown)";
			struct option const* o;
			for (o = long_options; o->val != 0; o++) {
				if (o->val == i) {
					opt = o->name;
					break;
				}
			}
			fprintf(stderr, "Missing option [--%s]\n", opt);
		}
	}
	die("RequiredOptions missing (%u,%u)\n", required, got);
}

int createSharedData(char const* name, void* data, size_t len)
{
	int fd = shm_open(name, O_RDWR|O_CREAT, 0600);
	if (fd < 0) return fd;
	int c = write(fd, data, len);
	if (c != len) return c;
	close(fd);
	return 0;
}
void createSharedDataOrDie(char const* name, void* data, size_t len)
{
	if (createSharedData(name, data, len) != 0) {
		die("createSharedData: %s\n", strerror(errno));
	}
}
void* mapSharedData(char const* name, size_t len, int mode)
{
	int fd = shm_open(name, mode, (mode == O_RDONLY)?0400:0600);
	if (fd < 0) return NULL;
	void* m = mmap(
		NULL, len,
		(mode == O_RDONLY)?PROT_READ:PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	if (m == MAP_FAILED) return NULL;
	return m;
}
void* mapSharedDataOrDie(char const* name, size_t len, int mode)
{
	void* m = mapSharedData(name, len, mode);
	if (m == NULL)
		die("mapSharedData %s\n", name);
	return m;
}


void maglevInit(struct MagData* m)
{
	initMagData(m, 997, 32);
	populate(m);
}
void maglevSetActive(struct MagData* m, unsigned v, int argc, char *argv[])
{
	while (argc-- > 0) {
		int i = atoi(*argv++);
		if (i >= 0 && i < m->N) m->active[i] = v;
	}
	populate(m);
}

