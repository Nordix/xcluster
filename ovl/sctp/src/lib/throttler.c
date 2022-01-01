/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include "throttler.h"
#include <die.h>
#include <stdlib.h>
#include <stdint.h>

static inline uint64_t toNanos(struct timespec const* t)
{
	return t->tv_sec * 1000000000 + t->tv_nsec;
}

struct Throttler {
	uint64_t start;				/* Start time in nanos */
	uint64_t interval;			/* Time between events in nS */
	uint64_t offset;			/* Random offset to prevent synced sends */
	unsigned events;			/* Event counter */
};

struct Throttler* throttler_create(struct timespec const* now, float rate)
{
	struct Throttler* t = calloc(1, sizeof(struct Throttler));
	if (t == NULL)
		die("OOM\n");
	t->start = toNanos(now);
	t->interval = (uint64_t)(1e9 / rate);
	t->offset = (uint64_t)rand() % t->interval;
	return t;
}

unsigned throttler_delay(struct Throttler* t, struct timespec const* _now)
{
	uint64_t now = toNanos(_now);
	uint64_t next = t->start + t->offset + t->events * t->interval;
	if (next <= now)
		return 0;
	return (next - now) / 1000;
}

void throttler_event(struct Throttler* t)
{
	t->events++;
}

