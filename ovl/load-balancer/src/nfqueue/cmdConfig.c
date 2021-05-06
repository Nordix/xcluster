/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "nfqueue.h"
#include <util.h>
#include <stdlib.h>


static int cmdActivate(int argc, char **argv)
{
	char const* shm = defaultTargetShm;
	struct Option options[] = {
		{"help", NULL, 0,
		 "activate [options]\n"
		 "  Activate a target or lb"},
		{"shm", &shm, 0, "Shared memory"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptionsOrDie(argc, argv, options);
	argc -= nopt;
	argv += nopt;
	struct SharedData* s;
	s = mapSharedDataOrDie(shm, sizeof(*s), O_RDWR);
	maglevSetActive(&s->magd, 1, argc, argv);
	return 0;
}

static int cmdDeactivate(int argc, char **argv)
{
	char const* shm = defaultTargetShm;
	struct Option options[] = {
		{"help", NULL, 0,
		 "deactivate [options]\n"
		 "  Deactivate a target or lb"},
		{"shm", &shm, 0, "Shared memory"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptionsOrDie(argc, argv, options);
	argc -= nopt;
	argv += nopt;
	struct SharedData* s;
	s = mapSharedDataOrDie(shm, sizeof(*s), O_RDWR);
	maglevSetActive(&s->magd, 0, argc, argv);
	return 0;
}

__attribute__ ((__constructor__)) static void addCommands(void) {
	addCmd("activate", cmdActivate);
	addCmd("deactivate", cmdDeactivate);
}
