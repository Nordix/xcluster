/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include "maglev.h"
#include <stdint.h>
#include <getopt.h>
#include <fcntl.h>
#include <unistd.h>

void die(char const* fmt, ...)__attribute__ ((__noreturn__));
uint32_t djb2_hash(uint8_t const* c, uint32_t len);
void verifyRequiredOptions(
	struct option const* long_options, unsigned required, unsigned got);

int macParse(char const* str, uint8_t* mac);
void macParseOrDie(char const* str, uint8_t* mac);
char const* macToString(uint8_t const* mac);

int createSharedData(char const* name, void* data, size_t len);
void createSharedDataOrDie(char const* name, void* data, size_t len);
void* mapSharedData(char const* name, size_t len, int mode);
void* mapSharedDataOrDie(char const* name, size_t len, int mode);

void maglevInit(struct MagData* m);
void maglevSetActive(struct MagData* m, unsigned v, int argc, char *argv[]);

void ipv4Print(unsigned len, uint8_t* pkt);
unsigned ipv4Hash(unsigned len, uint8_t* pkt);
void ipv6Print(unsigned len, uint8_t* pkt);
