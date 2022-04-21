#define _GNU_SOURCE
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>
#include <stdint.h>
#include <errno.h>

#include "../internal.h"

#define NAME_MAX 512
static char __path[NAME_MAX];
static int __fd;
static int __object_id;

/* 2MB buffer aligned with 512 (logical block size) for DIRECT IO  */
#define BUF_SIZE (2*1024*1024)
static char readbuf[BUF_SIZE] __attribute__((aligned(512)));

static int local_process_open_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_open *load;
	char *volume_key, *cookie_key;
	struct stat stats;
	char cmd[32];
	int ret, size;

	load = (void *)msg->data;
	volume_key = load->data;
	cookie_key = load->data + load->volume_key_size;

	printf("[OPEN] volume key %s (volume_key_size %lu), cookie key %s (cookie_key_size %lu), "
	       "object id %d, fd %d, flags %u\n",
		volume_key, load->volume_key_size, cookie_key, load->cookie_key_size,
		msg->object_id, load->fd, load->flags);

	ret = stat(cookie_key, &stats);
	if (ret) {
		printf("stat %s failed, %d (%s)\n", cookie_key, errno, strerror(errno));
		return -1;
	}
	size = stats.st_size;

	snprintf(cmd, sizeof(cmd), "copen %u,%lu", msg->msg_id, size);

	ret = write(devfd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write [copen] failed\n");
		return -1;
	}

	__object_id = msg->object_id;
	__fd = load->fd;
	strncpy(__path, cookie_key, NAME_MAX);

	return 0;
}

static int local_process_read_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_read *read;
	int i, ret, retval = -1;
	int dst_fd, src_fd;
	char *src_path = NULL;
	size_t len;
	unsigned long id;

	read = (void *)msg->data;

	src_path = __path;
	dst_fd = __fd;

	if (msg->object_id != __object_id) {
		printf("invalid object id\n");
		return -1;
	}

	printf("[READ] object_id %d, fd %d, src_path %s, off %llx, len %llx\n",
			msg->object_id, dst_fd, src_path, read->off, read->len);

	/* close cache prematurely */
	close(devfd);
	printf("done: close cache\n");

	src_fd = open(src_path, O_RDONLY);
	if (src_fd < 0) {
		printf("open src_path %s failed\n", src_path);
		return -1;
	}

	len = read->len;
	if (BUF_SIZE < len) {
		printf("buffer overflow\n");
		close(src_fd);
		return -1;
	}

	ret = pread(src_fd, readbuf, len, read->off);
	if (ret != len) {
		printf("read src image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		close(src_fd);
		return -1;
	}

	/* check writing to cache file when cache is already dead */
	ret = pwrite(dst_fd, readbuf, len, read->off);
	if (ret != len) {
		printf("write dst image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		/* continue */
	} else {
		printf("done: writing to cache file when cache is already dead\n");
	}

	/* check ioctl on anon_fd when cache is already dead */
	id = msg->msg_id;
	ret = ioctl(dst_fd, CACHEFILES_IOC_CREAD, id);
	if (ret < 0) {
		printf("expected: send cread failed, %d (%s)\n", errno, strerror(errno));
		/* continue */
	} else {
		printf("unexpected: ioctl on anon_fd when cache is already dead\n");
	}

	close(__fd);
	printf("done: close anon_fd\n");
	fflush(stdout);

	close(src_fd);
	return 0;
}

static int local_process_close_req(int devfd, struct cachefiles_msg *msg)
{
	if (msg->object_id != __object_id) {
		printf("invalid object id\n");
		return -1;
	}

	printf("[CLOSE] object_id %d, fd %d\n", msg->object_id, __fd);
	close(__fd);
	return 0;
}



static int process_one_req(int devfd)
{
	char buf[CACHEFILES_MSG_MAX_SIZE];
	int ret;
	struct cachefiles_msg *msg;
	size_t len;

	memset(buf, 0, sizeof(buf));

	ret = read(devfd, buf, sizeof(buf));
	if (ret < 0)
		printf("read devnode failed\n");
	if (ret <= 0)
		return -1;

	msg = (void *)buf;
	if (ret != msg->len) {
		printf("invalid message length %d (readed %d)\n", msg->len, ret);
		return -1;
	}

	switch (msg->opcode) {
	case CACHEFILES_OP_OPEN:
		return local_process_open_req(devfd, msg);
	case CACHEFILES_OP_CLOSE:
		return local_process_close_req(devfd, msg);
	case CACHEFILES_OP_READ:
		return local_process_read_req(devfd, msg);
	default:
		printf("invalid opcode %d\n", msg->opcode);
		return -1;
	}
}

int main(int argc, char *argv[])
{
	int fd, ret;
	char *cmd;
	char cmdbuf[128];
	char *fscachedir;
	struct pollfd pollfd;

	if (argc != 2) {
		printf("Using example: cachefilesd2 <fscachedir>\n");
		return -1;
	}

	fscachedir = argv[1];

	fd = daemon_get_devfd(fscachedir, NULL);
	if (fd < 0)
		return -1;

	pollfd.fd = fd;
	pollfd.events = POLLIN;

	while (1) {
		ret = poll(&pollfd, 1, -1);
		if (ret < 0) {
			printf("poll failed\n");
			close(fd);
			return -1;
		}

		if (ret == 0 || !(pollfd.revents & POLLIN)) {
			//printf("poll returned %d (%x)\n", ret, pollfd.revents);
			continue;
		}

		/* process all pending read requests */
		while (!process_one_req(fd)) {}
	}

	return 0;
}
