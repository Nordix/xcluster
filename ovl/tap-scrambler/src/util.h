/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

void addCmd(char const* name, int (*fn)(int argc, char* argv[]));
int tun_alloc(char const* dev, int flags);
int get_mtu(char const* dev);
