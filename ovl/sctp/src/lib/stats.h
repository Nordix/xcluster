#pragma once
/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include <stdio.h>
#include <time.h>

struct Stats {
	unsigned sent;
	unsigned received;
	unsigned maxRtt;			/* In milli seconds */
	/* Histogram */
	unsigned nBuckets;
	unsigned interval;			/* In micro seconds */
	unsigned buckets[];
};

/*
  Initiate the passed buffer. The length must be enough for the
  buckets array i.e >= sizeof(struct Stats) + nBuckets * sizeof(unsigned)
 */
void stats_init(void* buffer, unsigned nBuckets, unsigned interval);

/*
  Prepare a packet for sending.
 */
void stats_packet_prepare(
	struct timespec const* now, void* packet, unsigned len);

/*
  Report that a packet is sent. The "sent" counter is updated.
 */
void stats_packet_sent(struct Stats* stats);



/*
  Handle a received reply packet. The "received" counter and rtt stats
  are updated.
 */
void stats_packet_record(
	struct Stats* stats, struct timespec const* now, void const* packet, unsigned len);

/* Print functions */
void stats_print(FILE* out, struct Stats const* stats);
void stats_print_json(FILE* out, struct Stats const* stats);

