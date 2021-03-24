/*
   SPDX-License-Identifier: MIT License
   Copyright (c) 2021 Nordix Foundation
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/if_tun.h>
#include <net/if.h>

int tun_alloc(char const* dev, int flags) {

	if (dev == NULL) {
		return -1;
	}

	int fd;
	if((fd = open("/dev/net/tun" , O_RDWR)) < 0) {
		perror("Opening /dev/net/tun");
		return fd;
	}

	struct ifreq ifr;
	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_flags = flags | IFF_TAP;
	strncpy(ifr.ifr_name, dev, IFNAMSIZ);

	if(ioctl(fd, TUNSETIFF, (void*)&ifr) < 0) {
		perror("ioctl(TUNSETIFF)");
		close(fd);
		return -1;
	}

	return fd;
}

int get_mtu(char const* dev)
{
	int fd = socket(PF_INET, SOCK_DGRAM, 0);
	if (fd < 0) {
		perror("socket PF_INET");
		return -1;
	}
	struct ifreq ifr;
	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, dev);
	if (ioctl(fd, SIOCGIFMTU, &ifr) < 0) {
		perror("ioctl SIOCGIFMTU");
		return -1;
	}
	close(fd);
	return ifr.ifr_mtu;
}
