/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_CACHEFILES_H
#define _LINUX_CACHEFILES_H

#include <linux/types.h>
#include <linux/ioctl.h>

#define CACHEFILES_MSG_MAX_SIZE	1024

enum cachefiles_opcode {
	CACHEFILES_OP_OPEN,
	CACHEFILES_OP_CLOSE,
	CACHEFILES_OP_READ,
};

/*
 * @id		identifying position of this message in the radix tree
 * @opcode	message type, CACHEFILE_OP_*
 * @len		message length, including message header and following data
 * @data	message type specific payload
 */
struct cachefiles_msg {
	__u32 id;
	__u32 opcode;
	__u32 len;
	__u8  data[];
};

struct cachefiles_open {
	__u32 volume_key_len;
	__u32 cookie_key_len;
	__u32 fd;
	__u32 flags;
	/* following data contains volume_key and cookie_key in sequence */
	__u8  data[];
};

enum cachefiles_open_flags {
	CACHEFILES_OPEN_WANT_CACHE_SIZE,
};

struct cachefiles_close {
	__u32 fd;
};

struct cachefiles_read {
	__u64 off;
	__u64 len;
	__u32 fd;
};

#define CACHEFILES_IOC_CREAD    _IOW(0x98, 1, long)

#endif
