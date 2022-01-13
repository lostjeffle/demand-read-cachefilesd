#define _GNU_SOURCE
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>


int main(int argc, char *argv[])
{
	int ret;
	char *name;
	unsigned char fan;

	if (argc != 2) {
		printf("Using example: getfan <img_name>\n");
		return -1;
	}

	name = argv[1];

	/* strip the prefix 'D' of the path */
	fan = get_cookie_fan(name + 1);

	printf("You should put this image at cache/Ierofs/@%2x/%s\n",
		fan, name);

	return 0;
}
