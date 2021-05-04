#include <stdint.h>

uint32_t djb2_hash(uint8_t const* c, uint32_t len)
{
	uint32_t hash = 5381;
	while (len--)
		hash = ((hash << 5) + hash) + *c++; /* hash * 33 + c */
	return hash;
}

