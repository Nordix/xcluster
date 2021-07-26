#pragma once
/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include <stdio.h>

extern int loglevel;
extern char const* loglevelarg;

void loginit(void);

#define WARNING if(loglevel>=4)
#define NOTICE if(loglevel>=5)
#define INFO if(loglevel>=6)
#define DEBUG if(loglevel>=7)
#define warning(arg...) WARNING{printf(arg);}
#define notice(arg...) NOTICE{printf(arg);}
#define info(arg...) INFO{printf(arg);}
#define debug(arg...) DEBUG{printf(arg);}
