#include <stdio.h>
#include <sys/types.h>
#include <sys/resource.h>

int
main(int argc, char* argv[])
{
	printf("SIZEOF_PID_T %lu\n", sizeof(pid_t));
	printf("SIZEOF_UID_T %lu\n", sizeof(uid_t));
	printf("SIZEOF_GID_T %lu\n", sizeof(gid_t));
	printf("SIZEOF_TIME_T %lu\n", sizeof(time_t));
	printf("SIZEOF_RLIM_T %lu\n", sizeof(rlim_t));
	printf("SIZEOF_DEV_T %lu\n", sizeof(dev_t));
	printf("SIZEOF_INO_T %lu\n", sizeof(ino_t));
	return 0;
}
