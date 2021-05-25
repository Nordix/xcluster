/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "nfqueue.h"
#include <util.h>
#include <conntrack.h>
#include <stdlib.h>
#include <stdio.h>

char const* const defaultLbShm = "nfqueueLb";
char const* const defaultTargetShm = "nfqueueTarget";

static void initShm(char const* name, int ownFw, int fwOffset)
{
	struct SharedData s;
	s.ownFwmark = ownFw;
	s.fwOffset = fwOffset;
	maglevInit(&s.magd);
	createSharedDataOrDie(name, &s, sizeof(s));
}

static int cmdInit(int argc, char **argv)
{
	char const* targetShm = defaultTargetShm;
	char const* lbShm = defaultLbShm;
	char const* targetOffset = NULL;
	char const* lbOffset = NULL;
	char const* ownFw = NULL;
	struct Option options[] = {
		{"help", NULL, 0,
		 "init [options]\n"
		 "  Initiate shared mem structures"},
		{"ownfw", &ownFw, REQUIRED, "Own FW mark (not offset adjisted)"},
		{"tshm", &targetShm, 0, "Target shared memory"},
		{"toffset", &targetOffset, 0, "Target FW offset"},
		{"lbshm", &lbShm, 0, "Lb shared memory"},
		{"lboffset", &lbOffset, 0, "Lb FW offset"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	initShm(
		targetShm, atoi(ownFw), targetOffset == NULL ? 100:atoi(targetOffset));
	initShm(
		lbShm, atoi(ownFw), lbOffset == NULL ? 200:atoi(targetOffset));
	return 0;
}

static void showShm(char const* name)
{
	struct SharedData* s;
	s = mapSharedDataOrDie(name, sizeof(*s), O_RDONLY);
	printf("Shm: %s\n", name);
	printf("  Fw: own=%d, offset=%d\n", s->ownFwmark, s->fwOffset);
	printf("  Maglev: M=%d, N=%d\n", s->magd.M, s->magd.N);
	printf("   Lookup:");
	for (int i = 0; i < 25; i++)
		printf(" %d", s->magd.lookup[i]);
	printf("...\n");
	printf("   Active:");
	for (int i = 0; i < s->magd.N; i++)
		printf(" %u", s->magd.active[i]);
	printf("\n");
}

static int cmdShow(int argc, char **argv)
{
	char const* targetShm = defaultTargetShm;
	char const* lbShm = defaultLbShm;
	struct Option options[] = {
		{"help", NULL, 0,
		 "show [options]\n"
		 "  Show shared mem structures"},
		{"tshm", &targetShm, 0, "Target shared memory"},
		{"lbshm", &lbShm, 0, "Lb shared memory"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	showShm(lbShm);
	showShm(targetShm);
	return 0;
}

static int cmdStats(int argc, char **argv)
{
	char const* ftShm = "ftshm";
	struct Option options[] = {
		{"help", NULL, 0,
		 "stats [options]\n"
		 "  Show frag table stats"},
		{"ft_shm", &ftShm, 0, "Frag table; shared memory stats"},
		{0, 0, 0, 0}
	};
	(void)parseOptionsOrDie(argc, argv, options);
	struct ctStats* sft = mapSharedDataOrDie(ftShm, sizeof(*sft), O_RDONLY);
	printf(
		"size:         %u\n"
		"ttlNanos:     %lu\n"
		"collisions:   %u\n"
		"inserts:      %u (%u)\n"
		"lookups:      %u\n"
		"objGC:        %u\n",
		sft->size, sft->ttlNanos, sft->collisions, sft->inserts,
		sft->rejectedInserts, sft->lookups, sft->objGC);
	return 0;
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("init", cmdInit);
	addCmd("show", cmdShow);
	addCmd("stats", cmdStats);
}
