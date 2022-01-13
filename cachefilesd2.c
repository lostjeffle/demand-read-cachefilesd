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

#define CACHEFILES_ROOT	"/root/"
#define SRC_IMG_PATH "/root/"

int process_one_req(int fd)
{
	int ret, retval = -1;
	struct cachefiles_req_in req_in;
	int dst_fd, src_fd;
	char dst_path[NAME_MAX];
	char src_path[NAME_MAX];
	off64_t src_off, dst_off;
	char cmd[32];
	unsigned char fan;
	char *buffer;
	size_t len;

	ret = read(fd, &req_in, sizeof(req_in));
	if (ret < 0)
		printf("read /dev/cachefiles_ondemand failed\n");
	if (ret <= 0)
		goto err;

	printf("[id %llu %s] off %llx, len %llx\n", req_in.id, req_in.path, req_in.off, req_in.len);
	
	/* strip the prefix 'D' of the path */
	fan = get_cookie_fan(req_in.path + 1);

	snprintf(src_path, sizeof(src_path), "%s/%s", SRC_IMG_PATH, req_in.path);
	snprintf(dst_path, sizeof(dst_path), "%s/cache/Ierofs/@%2x/%s", CACHEFILES_ROOT, fan, req_in.path);

	src_fd = open(src_path, O_RDWR);
	if (src_fd < 0) {
		printf("open src_path %s failed\n", src_path);
		goto err;
	}

	dst_fd = open(dst_path, O_RDWR);
	if (dst_fd < 0) {
		printf("open dst_path %s failed\n", dst_path);
		goto err_srcfd;
	}

	len = req_in.len;
	buffer = malloc(len);
	if (!buffer) {
		printf("malloc failed\n");
		goto err_dstfd;
	}

	ret = pread(src_fd, buffer, len, req_in.off);
	if (ret != len) {
		printf("read src image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		goto err_buffer;
	}

	ret = pwrite(dst_fd, buffer, len, req_in.off);
	if (ret != len) {
		printf("write dst image failed, ret %d, %d (%s)\n", ret, errno, strerror(errno));
		goto err_buffer;
	}

	snprintf(cmd, sizeof(cmd), "done %llu", req_in.id);
	ret = write(fd, cmd, strlen(cmd));
	if (ret < 0) {
		printf("done failed\n");
		goto err_buffer;
	}

	retval = 0;

err_buffer:
	free(buffer);
err_dstfd:
	close(dst_fd);
err_srcfd:
	close(src_fd);
err:
	return retval;
}



int main(void)
{
	int fd, ret;
	char *cmd;
	char cmdbuf[NAME_MAX];
	struct pollfd pollfd;

	fd = open("/dev/cachefiles_ondemand", O_RDWR);
	if (fd < 0) {
		printf("open failed\n");
		return -1;
	}

	snprintf(cmdbuf, sizeof(cmdbuf), "dir %s", CACHEFILES_ROOT);
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
			continue;
		}

		/* process all pending read requests */
		while (!process_one_req(fd)) {}
	}

	return 0;
}
