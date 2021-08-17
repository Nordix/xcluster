/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include "stats.h"

#define CNTINC(x) __atomic_add_fetch(&(x),1,__ATOMIC_RELAXED)
#define CNTDEC(x) __atomic_sub_fetch(&(x),1,__ATOMIC_RELAXED)
#define ATOMIC_LOAD(x) __atomic_load_n(&(x),__ATOMIC_RELAXED)
#define ATOMIC_STORE(x,v) __atomic_store_n(&(x),v,__ATOMIC_RELAXED)

void stats_init(void* buffer, unsigned nBuckets, unsigned interval)
{
	struct Stats* stats = buffer;
	ATOMIC_STORE(stats->sent, 0);
	ATOMIC_STORE(stats->received, 0);
	ATOMIC_STORE(stats->maxRtt, 0);
	ATOMIC_STORE(stats->nBuckets, nBuckets);
	ATOMIC_STORE(stats->interval, interval);
	for (int i = 0; i < nBuckets; i++) {
		ATOMIC_STORE(stats->buckets[i], 0);
	}
}

void stats_packet_init(
	struct Stats* stats, struct timespec const* now,
	void* packet, unsigned len)
{
	CNTINC(stats->sent);
}

void stats_packet_record(
	struct Stats* stats, struct timespec const* now,
	void* packet, unsigned len)
{
	CNTINC(stats->received);
}

void stats_print(FILE* out, struct Stats const* stats)
{
	fprintf(out, "Sent:     %u\n", stats->sent);
	fprintf(out, "Received: %u\n", stats->received);
}
void stats_print_json(FILE* out, struct Stats const* stats)
{
}

