/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <getopt.h>
#include <unistd.h>
#include <linux/if_tun.h>

static void printPacket(uint8_t const* data, unsigned len);


static int cmdFwd(int argc, char* argv[])
{
	static struct option const long_options[] = {
		{"help",    no_argument,      0,  1 },
		{"tap",    required_argument, 0,  2 },
		{0,        0,                 0,  0 }
	};
	char const* dev;
	int fd = -1;
	int option_index = 0;
	int c = getopt_long_only(argc, argv, "", long_options, &option_index);
	while (c >= 0) {
		switch (c) {
		case 1:
			printf("fwd --tap=dev\n");
		case 2:
			dev = optarg;
			fd = tun_alloc(dev, IFF_NO_PI);
			break;
		default:
			return EXIT_FAILURE;
		}
		c = getopt_long_only(argc, argv, "", long_options, &option_index);
	}
	if (fd < 0) {
		fprintf(stderr, "Failed to create tap (or none specified)\n");
		return EXIT_FAILURE;
	}

	int mtu = get_mtu(dev);
	if (mtu < 0)
		return EXIT_FAILURE;
	printf("Using MTU %d\n", mtu);

	uint8_t buffer[mtu + 100];
	for (;;) {
		int cnt = read(fd, buffer, sizeof(buffer));
		if (cnt < 0)
			return EXIT_FAILURE;
		printPacket(buffer, cnt);
		if (write(fd, buffer, cnt) != cnt)
			return EXIT_FAILURE;
	}
	
	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCmdFwd(void) {
	addCmd("fwd", cmdFwd);
}


static void printPacket(uint8_t const* data, unsigned len)
{
	
}
