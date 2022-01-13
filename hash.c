#define _GNU_SOURCE
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>


#define GOLDEN_RATIO_32 0x61C88647

static inline uint32_t __hash_32_generic(uint32_t val)
{
	return val * GOLDEN_RATIO_32;
}

#define __hash_32 __hash_32_generic

/**
 * rol32 - rotate a 32-bit value left
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline uint32_t rol32(uint32_t word, unsigned int shift)
{
	return (word << (shift & 31)) | (word >> ((-shift) & 31));
}

/*
 * Mixing scores (in bits) for (7,20):
 * Input delta: 1-bit      2-bit
 * 1 round:     330.3     9201.6
 * 2 rounds:   1246.4    25475.4
 * 3 rounds:   1907.1    31295.1
 * 4 rounds:   2042.3    31718.6
 * Perfect:    2048      31744
 *             (32*64)   (32*31/2 * 64)
 */
#define HASH_MIX(x, y, a)	\
	(	x ^= (a),	\
	y ^= x,	x = rol32(x, 7),\
	x += y,	y = rol32(y,20),\
	y *= 9			)

static inline unsigned int fold_hash(unsigned long x, unsigned long y)
{
	/* Use arch-optimized multiply if one exists */
	return __hash_32(y ^ __hash_32(x));
}

/* x86 is little endian */
#define le32_to_cpu(x) (x)

/*
 * Generate a hash.  This is derived from full_name_hash(), but we want to be
 * sure it is arch independent and that it doesn't change as bits of the
 * computed hash value might appear on disk.  The caller must guarantee that
 * the source data is a multiple of four bytes in size.
 */
unsigned int fscache_hash(unsigned int salt, const void *data, size_t len)
{
	const uint32_t *p = data;
	unsigned int a, x = 0, y = salt, n = len / sizeof(uint32_t);

	for (; n; n--) {
		a = le32_to_cpu(*p++);
		HASH_MIX(x, y, a);
	}
	return fold_hash(x, y);
}

#define round_up(x, y) ((((x)-1) | ((y)-1)) + 1)

unsigned int get_volume_hash(const char *volume_key)
{
	int klen, hlen;
	char *key;
	unsigned int hash;

	klen = strlen(volume_key);
	hlen = round_up(1 + klen + 1, sizeof(uint32_t));

	key = malloc(hlen);
	if (!key) {
		printf("No memory\n");
		return 0;
	}

	memset(key, 0, hlen);
	key[0] = klen;
	memcpy(key + 1, volume_key, klen);

	hash = fscache_hash(0, key, hlen);
	free(key);

	return hash;
}

unsigned int get_cookie_hash(const char *cookie_key)
{
	int klen, hlen;
	char *key;
	unsigned int hash, volume_hash;

	klen = strlen(cookie_key);
	hlen = round_up(klen, sizeof(uint32_t));

	key = malloc(hlen);
	if (!key) {
		printf("No memory\n");
		return 0;
	}

	memset(key, 0, hlen);
	memcpy(key, cookie_key, klen);

	/* erofs kernel module registers volume with key "erofs" */
	volume_hash = get_volume_hash("erofs");
	hash = fscache_hash(volume_hash, key, hlen);
	free(key);

	return hash;
}

unsigned char get_cookie_fan(const char *cookie_key)
{
	/* cachefiles distributes all backing files over 256 fan directories */
	return get_cookie_hash(cookie_key);

}
