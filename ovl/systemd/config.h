#define _GNU_SOURCE

#define SIZEOF_PID_T 4
#define SIZEOF_UID_T 4
#define SIZEOF_GID_T 4
#define SIZEOF_TIME_T 8
#define SIZEOF_RLIM_T 8
#define SIZEOF_DEV_T 8
#define SIZEOF_INO_T 8

#define HAVE_SECURE_GETENV 1
#define HAVE_NAME_TO_HANDLE_AT 1
#define HAVE_SETNS 1
#define HAVE_LINUX_BTRFS_H 1
#define HAVE_ACL 0
#define HAVE_REALLOCARRAY 1
#define HAVE_STRUCT_STATX 1
#define HAVE_STRUCT_FIB_RULE_UID_RANGE 1

#define GPERF_LEN_TYPE size_t
#define DYNAMIC_UID_MIN 61184
#define DYNAMIC_UID_MAX 65519
#define SYSTEM_GID_MAX 65519
#define SYSTEM_UID_MAX 65519
#define PKGSYSCONFDIR "/etc/systemd"
#define PACKAGE_VERSION "236"
#define SYSTEMD_SHUTDOWN_BINARY_PATH "/bin/false"
#define SYSTEM_SHUTDOWN_PATH "/bin/false"
#define SYSTEMD_BINARY_PATH "/sbin/systemd"
#define SYSTEMD_CGROUP_AGENT_PATH "/bin/false"
#define SYSTEM_ENV_GENERATOR_PATH "/bin/false"
#define USER_ENV_GENERATOR_PATH "/bin/false"
#define PACKAGE_STRING "systemd"
#define DEFAULT_HIERARCHY_NAME "legacy"
#define DEFAULT_HIERARCHY 0
#define NOBODY_USER_NAME "nobody"
#define NOBODY_GROUP_NAME "nobody"
#define FALLBACK_HOSTNAME "ekvm"
#define UMOUNT_PATH "/bin/false"
#define MOUNT_PATH "/bin/false"
#define KEXEC "/bin/false"
#define SYSTEMD_FSCK_PATH "/bin/false"
#define SYSTEM_DATA_UNIT_PATH "/etc/systemd"
#define SYSTEMD_MAKEFS_PATH "/bin/false"
#define SYSTEMD_GROWFS_PATH "/bin/false"
#define USER_DATA_UNIT_PATH "/tmp"
#define SYSTEM_CONFIG_UNIT_PATH "/tmp"
#define USER_CONFIG_UNIT_PATH "/tmp"
#define SYSTEM_GENERATOR_PATH "/bin/false"
#define USER_GENERATOR_PATH "/bin/false"
#define SYSTEMD_TTY_ASK_PASSWORD_AGENT_BINARY_PATH "/bin/false"
#define ABS_BUILD_DIR "/tmp"
#define ABS_SRC_DIR "/tmp"
#define UDEVLIBEXECDIR "/tmp"
#define LIBDIR "/tmp"
#define TELINIT "/bin/false"
#define CATALOG_DATABASE "db"
#define MEMORY_ACCOUNTING_DEFAULT 0
#define ANSI_OK_COLOR "\033[32m"

// =0 disables settime
#define TIME_EPOCH 0

// "man textdomain"
#define GETTEXT_PACKAGE 0
