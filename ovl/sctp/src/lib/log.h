#pragma once
/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021-2022 Nordix Foundation
*/

#include <stdio.h>

extern int loglevel;
extern char const* loglevelarg;
extern FILE* logout;

void loginit(FILE* out);

#define WARNING if(loglevel>=4)
#define NOTICE if(loglevel>=5)
#define INFO if(loglevel>=6)
#define DEBUG if(loglevel>=7)
#define logf(arg...) fprintf(logout, arg)
#define warning(arg...) WARNING{logf(arg);}
#define notice(arg...) NOTICE{logf(arg);}
#define info(arg...) INFO{logf(arg);}
#define debug(arg...) DEBUG{logf(arg);}
