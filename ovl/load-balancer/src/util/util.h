/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021-2022 Nordix Foundation
*/

#include <stdint.h>
#include <time.h>

// MAC
int macParse(char const* str, uint8_t* mac);
void macParseOrDie(char const* str, uint8_t* mac);
char const* macToString(uint8_t const* mac);
int getMAC(char const* iface, /*out*/ unsigned char* mac);

// Print
void ipv4Print(unsigned len, uint8_t const* pkt);
void ipv6Print(unsigned len, uint8_t const* pkt);
void framePrint(unsigned len, uint8_t const* pkt);

// Csum (only ipv4 for now)
void tcpCsum(uint8_t* pkt, unsigned len);

