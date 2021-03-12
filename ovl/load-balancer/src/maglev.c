// gcc -o /tmp/maglev maglev.c maglev-test.c
// /tmp/maglev 1000 10 2 2

#include <stdlib.h>
#include <string.h>
#include "maglev.h"

void initMagData(struct MagData* d, unsigned m, unsigned n)
{
	memset(d, 0, sizeof(*d));
	d->M = m;
	d->N = n;
	for (int i = 0; i < d->N; i++) {
		unsigned offset = rand() % d->M;
		unsigned skip = rand() % (d->M - 1) + 1;
		unsigned j;
		for (j = 0; j < d->M; j++) {
			d->permutation[i][j] = (offset + j * skip) % d->M;
		}
	}
}

void populate(struct MagData* d)
{
	for (int i = 0; i < d->M; i++) {
		d->lookup[i] = -1;
	}

	// Corner case; no active targets
	unsigned nActive = 0;
	for (int i = 0; i < d->N; i++) {
		if (d->active[i] != 0) nActive++;
	}
	if (nActive == 0) return;
	
	unsigned next[MAX_N], c = 0;
	memset(next, 0, sizeof(next));
	unsigned n = 0;
	for (;;) {
		for (int i = 0; i < d->N; i++) {
			if (d->active[i] == 0) continue; /* Target not active */
			c = d->permutation[i][next[i]];
			while (d->lookup[c] >= 0) {
				next[i] = next[i] + 1;
				c = d->permutation[i][next[i]];
			}
			d->lookup[c] = i;
			next[i] = next[i] + 1;
			n = n + 1;
			if (n == d->M) return;
		}
	}
}

