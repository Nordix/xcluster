/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include "log.h"
#include <stdlib.h>

int loglevel = 0;
char const* loglevelarg = "5";

void loginit(void)
{
	loglevel = atoi(loglevelarg);
}
