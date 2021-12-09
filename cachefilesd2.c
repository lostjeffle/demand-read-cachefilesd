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

#define NAME_MAX         255	/* # chars in a file name */
struct cachefiles_req_in {
        uint64_t id;
        uint64_t off;
        uint64_t len;
        char path[NAME_MAX];
};

#define SRC_IMG_PATH "/root/Dtest.img"

int process_one_req(int fd)
{
	int ret;
	struct cachefiles_req_in req_in;
	int dst_fd, src_fd;
	char dst_path[NAME_MAX];
	off64_t src_off, dst_off;
	char cmd[32];
	char *buffer;
	size_t len;

	ret = read(fd, &req_in, sizeof(req_in));
	if (ret <= 0) {
		printf("read /dev/cachefiles failed\n");
		goto err;
	}
	printf("read %d, off %llu, len %llu, id %llu\n", ret, req_in.off, req_in.len, req_in.id);
	
	src_fd = open(SRC_IMG_PATH, O_RDWR);
	if (src_fd < 0) {
		printf("open src_fd %s failed\n", SRC_IMG_PATH);
		goto err;
	}

	snprintf(dst_path, sizeof(dst_path), "/root/cache/Ierofs/%s", req_in.path);

	dst_fd = open(dst_path, O_RDWR);
	if (dst_fd < 0) {
		printf("open dst_fd %s failed\n", dst_path);
		goto err_srcfd;
	}

	len = req_in.len;
	buffer = malloc(len);
	if (!buffer) {
		printf("malloc failed\n");
		goto err_dstfd;
	}

	ret = read(src_fd, buffer, len);
	if (ret != len) {
		printf("read src image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		goto err_buffer;
	}

	ret = write(dst_fd, buffer, len);
	if (ret != len) {
		printf("write dst image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		goto err_buffer;
	}

	/*
 	 * Writeback data to disk since fscache access backing file through
 	 * DIRECT IO currently.
 	 */
	ret = fsync(dst_fd);
	if (ret < 0) {
		printf("fdatasync failed\n");
		goto err_buffer;
	}

	snprintf(cmd, sizeof(cmd), "done %llu", req_in.id);
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("done failed\n");
		return -1;
	}

	return 0;

err_buffer:
	free(buffer);
err_dstfd:
	close(dst_fd);
err_srcfd:
	close(src_fd);
err:
	return -1;
}



int main(void)
{
	int fd, ret;
	char *cmd;
	struct pollfd pollfd;

	fd = open("/dev/cachefiles", O_RDWR);
	if (fd < 0) {
		printf("open failed\n");
		return -1;
	}

	cmd = "dir /root";
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write dir failed, %d\n", errno);
		close(fd);
		return -1;
	}

	cmd = "mode demand";
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("write mode failed, %d\n", errno);
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

	cmd = "bind";
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
			sleep(1);
			continue;
		}

		ret = process_one_req(fd);
		if (ret < 0)
			sleep(1);
	}

	return 0;
}
