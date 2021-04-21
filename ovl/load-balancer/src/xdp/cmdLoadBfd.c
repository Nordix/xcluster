/* 
   SPDX-License-Identifier: MIT
   Copyright (c) Nordix Foundation
*/

#include <util.h>
#include <stdlib.h>
#include <stdio.h>
#include <bpf/libbpf.h>
//#include <bpf/bpf.h>
#include <net/if.h>

static int cmdLoadBpf(int argc, char **argv)
{
	char const* dev;
	struct Option options[] = {
		{"help", NULL, 0,
		 "loadbpf [options] file\n"
		 "  Load a eBPF file to the kernel and attach to a device"},
		{"dev", &dev, REQUIRED,
		 "The eBPF program is attached to this device"},
		{0, 0, 0, 0}
	};
	int nopt = parseOptions(argc, argv, options);
	argc -= nopt;
	argv += nopt;
	if (argc <= 0)
		die("No eBPF file specified\n");
	unsigned int ifindex = if_nametoindex(dev);
	if (ifindex == 0)
		die("Unknown interface [%s]\n", dev);

	int first_prog_fd = -1;
	struct bpf_object *obj;
	int err = bpf_prog_load(*argv, BPF_PROG_TYPE_XDP, &obj, &first_prog_fd);
	if (err) die(
		"ERR: loading BPF-OBJ file(%s) (%d): %s\n", *argv, err, strerror(-err));

	char pin_dir[64];
	snprintf(pin_dir, sizeof(pin_dir), "/sys/fs/bpf/%s", dev);
	err = bpf_object__pin_maps(obj, pin_dir);
	if (err) die(
		"ERR: Pin BPF-map %s (%d): %s\n", pin_dir, err, strerror(-err));

	return EXIT_SUCCESS;
}
__attribute__ ((__constructor__)) static void addCmdFwd(void) {
	addCmd("loadbpf", cmdLoadBpf);
}
