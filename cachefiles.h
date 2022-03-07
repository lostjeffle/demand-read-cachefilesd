/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_CACHEFILES_H
#define _LINUX_CACHEFILES_H

#include <linux/types.h>

#define CACHEFILES_MSG_MAX_SIZE	512

enum cachefiles_opcode {
	CACHEFILES_OP_INIT,
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

struct cachefiles_init {
	__u32 volume_key_len;
	__u32 cookie_key_len;
	__u32 fd;
	__u32 flags;
	/* following data contains volume_key and cookie_key in sequence */
	__u8  data[];
};

enum cachefiles_init_flags {
	CACHEFILES_INIT_WANT_CACHE_SIZE,
};

#define CACHEFILES_INIT_FL_WANT_CACHE_SIZE	(1 << CACHEFILES_INIT_WANT_CACHE_SIZE)

struct cachefiles_read {
	__u64 off;
	__u64 len;
	__u32 fd;
};

#endif
