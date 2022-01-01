/*
   SPDX-License-Identifier: Apache-2.0
   Copyright (c) 2021-2022 Nordix Foundation
*/

#include <cmd.h>
#include <stdio.h>


int main(int argc, char *argv[])
{
	// Make logs to stdout/stderr appear when output is redirected
	setlinebuf(stdout);
	setlinebuf(stderr);

	return handleCmd(argc, argv);
}
