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

static int fd;
static char *imgdir;
static char *imgname;

static int check_inuse_state(void)
{
	char *tmp;
	char cmdbuf[128];
	char cwd[128];
	int ret;

	tmp = getcwd(cwd, sizeof(cwd));
	if (!tmp) {
		printf("getcwd failed %d (%s)\n", errno, strerror(errno));
		return -1;
	}

	ret = chdir(imgdir);
	if (ret) {
		printf("chdir failed %d (%s)\n", errno, strerror(errno));
		return -1;
	}

	snprintf(cmdbuf, sizeof(cmdbuf), "inuse %s", imgname);
	ret = write(fd, cmdbuf, strlen(cmdbuf));
	if (ret < 0)
		printf("%s/%s is inuse, %d (%s)\n", imgdir, imgname, errno, strerror(errno));
	else {
		printf("%s/%s is not inuse\n", imgdir, imgname);

		snprintf(cmdbuf, sizeof(cmdbuf), "cull %s", imgname);
		ret = write(fd, cmdbuf, strlen(cmdbuf));
		if (ret < 0)
			printf("%s/%s failed to cull since it's inuse, %d (%s)\n", imgdir, imgname, errno, strerror(errno));
		else
			printf("%s/%s is culled\n", imgdir, imgname);
	}

	fflush(stdout);
	chdir(cwd);
	return ret;
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
		return process_open_req(devfd, msg);
	case CACHEFILES_OP_CLOSE:
		ret = process_close_req(devfd, msg);
		check_inuse_state();
		return ret;
	case CACHEFILES_OP_READ:
		ret = process_read_req(devfd, msg);
		check_inuse_state();
		return ret;
	default:
		printf("invalid opcode %d\n", msg->opcode);
		return -1;
	}
}

int main(int argc, char *argv[])
{
	int ret;
	char *cmd;
	char cmdbuf[128];
	char *fscachedir;
	struct pollfd pollfd;

	if (argc != 4) {
		printf("Using example: cachefilesd2 <fscachedir>\n");
		return -1;
	}

	fscachedir = argv[1];
	imgdir = argv[2];
	imgname = argv[3];

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
