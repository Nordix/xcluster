/* 
   SPDX-License-Identifier: MIT
   Copyright 2021 (c) Nordix Foundation
*/

#include <linux/if_ether.h>

struct SharedData {
	struct MagData m;
	unsigned char target[MAX_N][ETH_ALEN];
};
char const* const defaultShmName;
