/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

//#include <stdint.h>
//#include <fcntl.h>
//#include <unistd.h>


void die(char const* fmt, ...)__attribute__ ((__noreturn__));

// addCmd should be defined in main.c
void addCmd(char const* name, int (*fn)(int argc, char* argv[]));
struct Option {
	char const* const name;
	char const** arg;
#define REQUIRED 1
#define OPTIONAL 0
	int required;
	char const* const help;
};
// Returns number of handled items, < 0 on error, 0 on help
int parseOptions(int argc, char* argv[], struct Option const* options);
int parseOptionsOrDie(int argc, char* argv[], struct Option const* options);

