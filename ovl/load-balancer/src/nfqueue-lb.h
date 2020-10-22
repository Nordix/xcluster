/*
  The shared memory structure for nfqueue-lb.
 */

#include "maglev.h"

#define MEM_NAME "nfqueue-lb"
struct SharedData {
	int ownFwmark;
	struct MagData magd;
	struct {
		int nActive;
		int lookup[MAX_N];
	} modulo;
};
