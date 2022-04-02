#define _GNU_SOURCE
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>
#include <stdint.h>
#include <errno.h>

#include "../internal.h"

static int policy;

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

	printf("[HEADER] id %u, opcode %d\t", msg->id, msg->opcode);

	switch (msg->opcode) {
	case CACHEFILES_OP_OPEN:
		if (policy & 1)
			return process_open_req(devfd, msg);
		else
			return process_open_req_fail(devfd, msg);

	case CACHEFILES_OP_READ:
		if (policy & 2)
			return process_read_req(devfd, msg);
		else
			return process_read_req_fail(devfd, msg);
	case CACHEFILES_OP_CLOSE:
		if (policy & 4)
			return process_close_req(devfd, msg);
		else
			return process_close_req_fail(devfd, msg);
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

	if (argc != 3) {
		printf("Using example: cachefilesd2 <fscachedir> <policy>\n");
		return -1;
	}

	fscachedir = argv[1];
	policy = atoi(argv[2]);

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
			printf("poll returned %d (%x)\n", ret, pollfd.revents);
			continue;
		}

		/* process all pending read requests */
		while (!process_one_req(fd)) {}
	}

	return 0;
}
