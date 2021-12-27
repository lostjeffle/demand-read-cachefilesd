#include <sys/xattr.h>
#include <stdio.h>
#include <stdint.h>

struct cachefiles_xattr {
	uint64_t	object_size;	/* Actual size of the object */
	uint64_t	zero_point;	/* Size after which server has no data not written by us */
	uint8_t	type;		/* Type of object */
	uint8_t	content;	/* Content presence (enum cachefiles_content) */
	uint8_t	data[];		/* netfs coherency data */
} __attribute__((__packed__));

#define CACHEFILES_COOKIE_TYPE_DATA 1

enum cachefiles_content {
	/* These values are saved on disk */
	CACHEFILES_CONTENT_NO_DATA	= 0, /* No content stored */
	CACHEFILES_CONTENT_SINGLE	= 1, /* Content is monolithic, all is present */
	CACHEFILES_CONTENT_ALL		= 2, /* Content is all present, no map */
	CACHEFILES_CONTENT_BACKFS_MAP	= 3, /* Content is piecemeal, mapped through backing fs */
	CACHEFILES_CONTENT_DIRTY	= 4, /* Content is dirty (only seen on disk) */
	nr__cachefiles_content
};


/*
 * X86 is little endian, while 'object_size' is stored as big endian.
 */
#define ___constant_swab64(x) ((uint64_t)(				\
	(((uint64_t)(x) & (uint64_t)0x00000000000000ffULL) << 56) |	\
	(((uint64_t)(x) & (uint64_t)0x000000000000ff00ULL) << 40) |	\
	(((uint64_t)(x) & (uint64_t)0x0000000000ff0000ULL) << 24) |	\
	(((uint64_t)(x) & (uint64_t)0x00000000ff000000ULL) <<  8) |	\
	(((uint64_t)(x) & (uint64_t)0x000000ff00000000ULL) >>  8) |	\
	(((uint64_t)(x) & (uint64_t)0x0000ff0000000000ULL) >> 24) |	\
	(((uint64_t)(x) & (uint64_t)0x00ff000000000000ULL) >> 40) |	\
	(((uint64_t)(x) & (uint64_t)0xff00000000000000ULL) >> 56)))
#define cpu_to_be64(x) ___constant_swab64((x))

int main(int argc, char *argv[])
{
	int ret;
	struct cachefiles_xattr xattr;
	char *path;
	unsigned long size;

	if (argc != 3) {
		printf("invalid argc\n");
		return -1;
	}

	path = argv[1];
	size = atoi(argv[2]);

	xattr = (struct cachefiles_xattr) {
		.object_size = cpu_to_be64(size),
		.zero_point = 0,
		.type = CACHEFILES_COOKIE_TYPE_DATA,
		.content = CACHEFILES_CONTENT_NO_DATA,
	};

	ret = setxattr(path, "user.CacheFiles.cache", &xattr, sizeof(xattr), 0);
	if (!ret)
		printf("sccuess\n");

	return 0;
}
