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
#include <sys/prctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "../internal.h"

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
		return process_open_req(devfd, msg);
	case CACHEFILES_OP_CLOSE:
		return process_close_req(devfd, msg);
	case CACHEFILES_OP_READ:
		sleep(1);
		return process_read_req(devfd, msg);
	default:
		printf("invalid opcode %d\n", msg->opcode);
		return -1;
	}
}

static int handle_requests(int devfd)
{
	int ret = 0;
	struct pollfd pollfd;

	pollfd.fd = devfd;
	pollfd.events = POLLIN;

	while (1) {
		ret = poll(&pollfd, 1, -1);
		if (ret < 0) {
			printf("poll failed\n");
			return -1;
		}

		if (ret == 0 || !(pollfd.revents & POLLIN)) {
			printf("poll returned %d (%x)\n", ret, pollfd.revents);
			continue;
		}

		/* process all pending read requests */
		while (!process_one_req(devfd)) {}
	}

	return 0;
}

static int startup_child_process(int devfd)
{
	pid_t pid;
	int wstatus = 0;

restart:
	pid = fork();
	if (pid == 0) {
		/* child process */
		printf("child[pid %d]: start to handle requests\n", getpid());
		handle_requests(devfd);
	} else if (pid > 0)  {
		/* parent process */
		printf("supervisor[pid %d]: fork child process\n", getpid());
		prctl(PR_SET_NAME, "cache-child",NULL,NULL,NULL);
		if (pid == wait(&wstatus)) {
			if (WIFSIGNALED(wstatus)) {
				ssize_t written = write(devfd, "restore", 7);
				if (written != 7) {
					printf("supervisor: write restore cmd recover failed\n");
					return -1;
				}
				printf("supervisor: restore in-flight IO success, restart child process...\n");
				goto restart;
			}
		}
	}

	return pid;
}

int main(int argc, char *argv[])
{
	int fd, ret;
	char *fscachedir;

	if (argc != 2) {
		printf("Using example: cachefilesd2 <fscachedir>\n");
		return -1;
	}

	fscachedir = argv[1];

	fd = daemon_get_devfd(fscachedir, "test");
	if (fd < 0)
		return -1;

	return startup_child_process(fd);
}
