/* 
   SPDX-License-Identifier: MIT
   Copyright 2021 (c) Nordix Foundation
*/

#include "util.h"
#include "shm.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

char const* const defaultShmName = "xdplb";

static int cmdInit(int argc, char* argv[])
{
	char const* shmName = defaultShmName;
	struct Option options[] = {
		{"help", NULL, 0,
		 "init [options]\n"
		 "  Initiate the shm structure"},
		{"shm", &shmName, 0, "Shared memory struct to create"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;

	struct SharedData sh;
	memset(&sh, 0, sizeof(sh));
	maglevInit(&sh.m);
	createSharedDataOrDie(shmName, &sh, sizeof(sh)); 
	return 0;
}

static int cmdShow(int argc, char* argv[])
{
	char const* shmName = defaultShmName;
	struct Option options[] = {
		{"help", NULL, 0,
		 "show [options]\n"
		 "  Show LB status"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;

	struct SharedData* sh = mapSharedDataOrDie(
		shmName, sizeof(struct SharedData), O_RDONLY);
	printf("M=%u, N=%u, lookup;\n", sh->m.M, sh->m.N);
	for (int i = 0; i < 24; i++) {
		printf("%d ", sh->m.lookup[i]);
	}
	printf("...\n");
	printf("Active:\n");
	for (int i = 0; i < sh->m.N; i++) {
		if (sh->m.active[i] == 0)
			continue;
		printf("  %-2d: %s\n", i, macToString(sh->target[i]));
	}
	return 0;
}

static int setActive(int argc, char* argv[], int v)
{
	char const* shmName = defaultShmName;
	char const* mac = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "(de)activate [options] <index>\n"
		 "  Activate/deactivate a target"},
		{"shm", &shmName, 0, "Shared memory struct created by 'init'"},
		{"mac", &mac, 0, "MAC address for the target"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	if (nopt < 1) return nopt;
	argc -= nopt;
	argv += nopt;
	
	if (argc < 1) {
		printf("No index\n");
		return 0;
	}
	unsigned i = atoi(argv[0]);

	struct SharedData* sh = mapSharedDataOrDie(
		shmName, sizeof(struct SharedData), O_RDWR);

	if (i >= sh->m.N) {
		printf("Invalid index [%u]\n", i);
		return 1;
	}

	if (mac != NULL) {
		macParseOrDie(mac, sh->target[i]);
	}
	if (v >= 0) {
		sh->m.active[i] = v;
		populate(&sh->m);
	}
	return 0;
}
static int cmdActivate(int argc, char* argv[])
{
	return setActive(argc, argv, 1);
}
static int cmdDeactivate(int argc, char* argv[])
{
	return setActive(argc, argv, 0);
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("init", cmdInit);
	addCmd("activate", cmdActivate);
	addCmd("deactivate", cmdDeactivate);
	addCmd("show", cmdShow);
}
