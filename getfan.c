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
	char *volume, *img;
	unsigned char fan;

	if (argc != 3) {
		printf("Using example: getfan <volume> <img_name>\n");
		return -1;
	}

	volume = argv[1];
	img  = argv[2];

	fan = get_cookie_fan(volume, img);
	printf("%2x\n", fan);

	return 0;
}
