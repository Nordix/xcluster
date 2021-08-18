#pragma once
/*
  SPDX-License-Identifier: Apache-2.0
  Copyright (c) 2021 Nordix Foundation
*/

#include <time.h>

struct Throttler;

struct Throttler* throttler_create(struct timespec const* now, float rate);

/*
  throttler_delay returns the delay in micro seconds until the next
  event.
 */
unsigned throttler_delay(struct Throttler* t, struct timespec const* now);

/*
  throttler_event "consumes" an event.
 */
void throttler_event(struct Throttler* t);
