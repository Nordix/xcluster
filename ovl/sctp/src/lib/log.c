/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include "log.h"
#include <stdlib.h>

int loglevel = 5;
char const* loglevelarg = "5";
FILE* logout = NULL;

void loginit(FILE* out)
{
	logout = out;
	loglevel = atoi(loglevelarg);
}
