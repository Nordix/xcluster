/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include "stats.h"
#include <string.h>
#include <stdint.h>

#define CNTINC(x) __atomic_add_fetch(&(x),1,__ATOMIC_RELAXED)
#define CNTDEC(x) __atomic_sub_fetch(&(x),1,__ATOMIC_RELAXED)
#define ATOMIC_LOAD(x) __atomic_load_n(&(x),__ATOMIC_RELAXED)
#define ATOMIC_STORE(x,v) __atomic_store_n(&(x),v,__ATOMIC_RELAXED)

static inline uint64_t toNanos(struct timespec const* t)
{
	return t->tv_sec * 1000000000 + t->tv_nsec;
}
// Diff in micro seconds
static unsigned timeDiff(struct timespec const* a, struct timespec const* b)
{
	return (unsigned)((toNanos(a) - toNanos(b)) / 1000);
}

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

void stats_packet_prepare(
	struct timespec const* now, void* packet, unsigned len)
{
	if (len >= sizeof(struct timespec)) {
		memcpy(packet, now, sizeof(struct timespec));
	}
}
void stats_packet_sent(struct Stats* stats)
{
	CNTINC(stats->sent);
}

void stats_packet_record(
	struct Stats* stats, struct timespec const* now,
	void const* packet, unsigned len)
{
	CNTINC(stats->received);
	if (len < sizeof(struct timespec))
		return;
	struct timespec const* sent = packet;
	unsigned rtt = timeDiff(now, sent);
	unsigned rttMS = rtt / 1000;
	if (rttMS > stats->maxRtt)
		ATOMIC_STORE(stats->maxRtt, rttMS);

	// Update the histogram
	if (stats->nBuckets < 1)
		return;
	if (rtt >= ((stats->nBuckets - 1) * stats->interval)) {
		CNTINC(stats->buckets[stats->nBuckets - 1]);
		return;					/* Last bucket or more */
	}
	for (int i = 0; i < (stats->nBuckets - 1); i++) {
		if (rtt < ((i + 1) * stats->interval)) {
			CNTINC(stats->buckets[i]);
			return;
		}
	}
}

void stats_print(FILE* out, struct Stats const* stats)
{
	fprintf(out, "Sent:     %u\n", stats->sent);
	fprintf(out, "Received: %u\n", stats->received);
	fprintf(out, "MaxRTT:   %u\n", stats->maxRtt);
	fprintf(out, "Interval: %u\n", stats->interval);
	if (stats->nBuckets < 1)
		return;

	unsigned max = 0;
	for (int i = 0; i < stats->nBuckets; i++) {
		if (stats->buckets[i] > max)
			max = stats->buckets[i];
	}
	if (max == 0)
		max = 1;				/* Prevent divide by zero */

	char bar[80];
	memset(bar, '=', sizeof(bar));
	for (int i = 0; i < stats->nBuckets; i++) {
		unsigned l = stats->buckets[i] * 64 / max;
		bar[l] = 0;
		fprintf(out, "%6u |%s\n", stats->buckets[i], bar);
		bar[l] = '=';
	}
}
#define str(a) #a
#define JUNSIGNED(x) "  \"%s\": %u,\n", str(x), stats->x
void stats_print_json(FILE* out, struct Stats const* stats)
{
	fprintf(out, "{\n");
	fprintf(out, JUNSIGNED(sent));
	fprintf(out, JUNSIGNED(received));
	fprintf(out, JUNSIGNED(maxRtt));
	fprintf(out, JUNSIGNED(nBuckets));
	fprintf(out, JUNSIGNED(interval));
	fprintf(out, "  \"buckets\": [\n");
	if (stats->nBuckets > 0) {
		for (int i = 0; i < (stats->nBuckets - 1); i++) {
			fprintf(out, "    %u,\n", stats->buckets[i]);
		}
		fprintf(out, "    %u\n", stats->buckets[stats->nBuckets - 1]);
	}
	fprintf(out, "  ]\n");
	fprintf(out, "}\n");
}

