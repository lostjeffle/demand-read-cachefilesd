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

/* uapi for cahcefiles */
#include "cachefiles.h"

#define NAME_MAX 512
struct fd_path_link {
	int fd;
	char path[NAME_MAX];
} links[32];

unsigned int link_num = 0;

char *fscachedir;

/* 2MB buffer aligned with 512 (logical block size) for DIRECT IO  */
#define BUF_SIZE (2*1024*1024)
char buffer[BUF_SIZE] __attribute__((aligned(512)));

static int get_file_size(char *path)
{
	struct stat stats;
	int ret;

	ret = stat(path, &stats);
	if (ret) {
		printf("stat %s failed\n", path);
		return -1;
	}

	return stats.st_size;
}

static int process_open_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_open *load;
	struct fd_path_link *link;
	char *volume_key, *cookie_key;
	char cmd[32];
	int ret, size;

	load = (void *)msg->data;
	volume_key = load->data;
	cookie_key = load->data + load->volume_key_len;

	printf("[OPEN] volume key %s (volume_key_len %lu), cookie key %s (cookie_key_len %lu), fd %d, flags %u\n",
		volume_key, load->volume_key_len, cookie_key, load->cookie_key_len, load->fd, load->flags);

	size = get_file_size(cookie_key);
	if (size < 0)
		return -1;

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

static int process_close_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_close *load;

	load = (void *)msg->data;

	printf("[CLOSE] fd %d\n", load->fd);
	close(load->fd);
	return 0;
}

static char *get_src_path(int fd)
{
	struct fd_path_link *link;
	int i;

	for (i = 0; i < link_num; i++) {
		link = links + i;
		if (link->fd == fd)
			return link->path;
	}

	printf("failed get_src_path of %d\n", fd);
	return NULL;
}

static int process_read_req(int devfd, struct cachefiles_msg *msg)
{
	struct cachefiles_read *read;
	int ret, retval = -1;
	int dst_fd, src_fd;
	char *src_path;
	size_t len;
	unsigned long id;

	read = (void *)msg->data;

	src_path = get_src_path(read->fd);
	if (!src_path)
		return -1;

	printf("[READ] fd %d, src_path %s, off %llx, len %llx\n", read->fd, src_path, read->off, read->len);

	dst_fd = read->fd;
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

	ret = pread(src_fd, buffer, len, read->off);
	if (ret != len) {
		printf("read src image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		close(src_fd);
		return -1;
	}

	ret = pwrite(dst_fd, buffer, len, read->off);
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
		return process_open_req(devfd, msg);
	case CACHEFILES_OP_CLOSE:
		return process_close_req(devfd, msg);
	case CACHEFILES_OP_READ:
		return process_read_req(devfd, msg);
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
	struct pollfd pollfd;

	if (argc != 2) {
		printf("Using example: cachefilesd2 <fscachedir>\n");
		return -1;
	}

	fscachedir = argv[1];

	fd = open("/dev/cachefiles", O_RDWR);
	if (fd < 0) {
		printf("open /dev/cachefiles failed\n");
		return -1;
	}

	snprintf(cmdbuf, sizeof(cmdbuf), "dir %s", fscachedir);
	ret = write(fd, cmdbuf, strlen(cmdbuf));
	if (ret < 0) {
		printf("write dir failed, %d\n", errno);
		close(fd);
		return -1;
	}

	cmd = "tag test";
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write tag failed, %d\n", errno);
		close(fd);
		return -1;
	}

	cmd = "bind ondemand";
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("bind failed\n");
		close(fd);
		return -1;
	}

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
