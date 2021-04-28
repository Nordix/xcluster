/* 
   SPDX-License-Identifier: MIT
   Copyright 2021 (c) Nordix Foundation
*/

#include <xcutil.h>
#include <stdlib.h>
#include <stdio.h>

static int cmdTemplate(int argc, char **argv)
{
	char const* req;
	char const* opt = "Not specified";
	struct Option options[] = {
		{"help", NULL, 0,
		 "template [options]\n"
		 "  An xcutil command template"},
		{"req", &req, REQUIRED,
		 "A required option"},
		{"opt", &opt, OPTIONAL,
		 "A optional option"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptionsOrDie(argc, argv, options);
	argc -= nopt;
	argv += nopt;	

	printf("req = [%s], opt = [%s]\n", req, opt);
	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCommand(void) {
	addCmd("template", cmdTemplate);
}
