/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_COMMANDS 20
struct Cmd {
	char const* name;
	int (*fn)(int argc, char* argv[]);
};
static struct Cmd cmd[MAX_COMMANDS + 1] = {{NULL, NULL}};
void addCmd(char const* name, int (*fn)(int argc, char* argv[]))
{
	struct Cmd* c = cmd;
	while (c->name != NULL) c++;
	if (c - cmd < MAX_COMMANDS) {
		c->name = name;
		c->fn = fn;
	}
}

int main(int argc, char *argv[])
{
	if (argc < 2) {
		printf("Usage: %s <command> [opt...]\n", argv[0]);
		for (struct Cmd const* c = cmd; c->name != NULL; c++) {
			printf("  %s\n", c->name);
		}
		exit(EXIT_FAILURE);
	}

	argc--;
	argv++;
	for (struct Cmd* c = cmd; c->fn != NULL; c++) {
		if (strcmp(*argv, c->name) == 0)
			return c->fn(argc, argv);
	}

	printf("Uknnown command [%s]\n", *argv);
	return EXIT_FAILURE;
}
