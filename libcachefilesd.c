#define _GNU_SOURCE
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <poll.h>
#include <stdint.h>

#include "internal.h"


#define NAME_MAX 512
struct fd_path_link {
	int fd;
	char path[NAME_MAX];
} links[32];

unsigned int link_num = 0;

int process_open_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_open *load;
	struct fd_path_link *link;
	char *volume_key, *cookie_key;
	struct stat stats;
	char cmd[32];
	int ret, size;

	load = (void *)msg->data;
	volume_key = load->data;
	cookie_key = load->data + load->volume_key_len;

	printf("[OPEN] volume key %s (volume_key_len %lu), cookie key %s (cookie_key_len %lu), fd %d, flags %u\n",
		volume_key, load->volume_key_len, cookie_key, load->cookie_key_len, load->fd, load->flags);

	ret = stat(cookie_key, &stats);
	if (ret) {
		printf("stat %s failed, %d (%s)\n", cookie_key, errno, strerror(errno));
		return -1;
	}
	size = stats.st_size;

	snprintf(cmd, sizeof(cmd), "copen %u,%lu", msg->id, size);
	printf("Writing cmd: %s\n", cmd);

	ret = write(devfd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write [copen] failed\n");
		return -1;
	}

	if (link_num >= 32)
		return -1;

	link = links + link_num;
	link_num ++;

	link->fd = load->fd;
	strncpy(link->path, cookie_key, NAME_MAX);

	return 0;
}

/* error injection - return error directly */
int process_open_req_fail(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_open *load;
	char *volume_key, *cookie_key;
	char cmd[32];
	int ret, size;

	load = (void *)msg->data;
	volume_key = load->data;
	cookie_key = load->data + load->volume_key_len;

	printf("[OPEN] volume key %s (volume_key_len %lu), cookie key %s (cookie_key_len %lu), fd %d, flags %u\n",
		volume_key, load->volume_key_len, cookie_key, load->cookie_key_len, load->fd, load->flags);

	snprintf(cmd, sizeof(cmd), "copen %u,-1", msg->id);
	printf("Writing cmd: %s\n", cmd);

	ret = write(devfd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write [copen] failed\n");
		return -1;
	}

	return 0;
}

int process_close_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_close *load;

	load = (void *)msg->data;

	printf("[CLOSE] fd %d\n", load->fd);
	close(load->fd);
	return 0;
}


/* 2MB buffer aligned with 512 (logical block size) for DIRECT IO  */
#define BUF_SIZE (2*1024*1024)
static char readbuf[BUF_SIZE] __attribute__((aligned(512)));

int process_read_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_read *read;
	struct fd_path_link *link;
	int i, ret, retval = -1;
	int dst_fd, src_fd;
	char *src_path = NULL;
	size_t len;
	unsigned long id;

	read = (void *)msg->data;

	/* get source path of this anon_fd */
	dst_fd = read->fd;
	for (i = 0; i < link_num; i++) {
		link = links + i;
		if (link->fd == dst_fd) {
			src_path = link->path;
			break;
		}
	}

	if (!src_path) {
		printf("failed get_src_path of %d\n", dst_fd);
		return -1;
	}

	printf("[READ] fd %d, src_path %s, off %llx, len %llx\n", read->fd, src_path, read->off, read->len);

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

	ret = pwrite(dst_fd, readbuf, len, read->off);
	if (ret != len) {
		printf("write dst image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		close(src_fd);
		return -1;
	}

	id = msg->id;
	ret = ioctl(dst_fd, CACHEFILES_IOC_CREAD, id);
	if (ret < 0) {
		printf("send cread failed, %d (%s)\n", errno, strerror(errno));
		close(src_fd);
		return -1;
	}

	close(src_fd);
	return 0;
}


int daemon_get_devfd(const char *fscachedir, const char *tag)
{
	char *cmd;
	char cmdbuf[128];
	int fd, ret;

	if (!fscachedir)
		return -1;

	fd = open("/dev/cachefiles", O_RDWR);
	if (fd < 0) {
		printf("open /dev/cachefiles failed\n");
		return -1;
	}

	snprintf(cmdbuf, sizeof(cmdbuf), "dir %s", fscachedir);
	ret = write(fd, cmdbuf, strlen(cmdbuf));
	if (ret < 0) {
		printf("write dir failed, %d\n", errno);
		goto error;
	}

	if (tag) {
		snprintf(cmdbuf, sizeof(cmdbuf), "tag %s", tag);
		ret = write(fd, cmdbuf, strlen(cmdbuf));
		if (ret < 0) {
			printf("write tag failed, %d\n", errno);
			goto error;
		}
	}

	cmd = "bind ondemand";
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("bind failed\n");
		goto error;
	}

	return fd;
error:
	close(fd);
	return -1;
}
