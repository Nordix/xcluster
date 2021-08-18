/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include <throttler.h>
#include <stdio.h>
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

#define D(x)
#define Dx(x) x

// White-box testing;
struct Throttler {
	uint64_t start;			/* Start time in nanos */
	uint64_t interval;		/* Time between events in nS */
	uint64_t offset;		/* Random offset to prevent synced sends */
	unsigned events;		/* Event counter */
};



int
main(int argc, char* argv[])
{
	srand(55);
	struct timespec now = {0};
	unsigned delay;
	struct Throttler* t = throttler_create(&now, 1000.0);
	D(printf("interval = %lu\n", t->interval));
	assert(t->interval == 1000000);
	delay = throttler_delay(t, &now);
	D(printf("delay = %u\n", delay));
	assert(delay == 587);
	throttler_event(t);
	delay = throttler_delay(t, &now);
	D(printf("delay = %u\n", delay));
	assert(delay == 1587);
	now.tv_nsec += 1000000;
	delay = throttler_delay(t, &now);
	D(printf("delay = %u\n", delay));
	assert(delay == 587);
	now.tv_nsec += 1000000;
	delay = throttler_delay(t, &now);
	D(printf("delay = %u\n", delay));
	assert(delay == 0);

	
	printf("=== throttler-test OK\n");
	return 0;
}
