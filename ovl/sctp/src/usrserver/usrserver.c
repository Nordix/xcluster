/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <arpa/inet.h>

extern int echo_server_main(int argc, char *argv[]);
extern uint32_t override_vtag;

int
main(int argc, char *argv[])
{
	setlinebuf(stdout);
	setlinebuf(stderr);
	if (argc < 2) {
		fprintf(stderr, "No vtag\n");
		return -1;
	}
	override_vtag = htonl(atoi(argv[1]));
	printf("override_vtag = %u\n", ntohl(override_vtag));
	return echo_server_main(argc - 1 , argv + 1);
}
