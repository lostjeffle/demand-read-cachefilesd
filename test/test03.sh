#!/bin/bash
#
# Test remounting one erofs fs when the backend user daemon has changed
# with different tag.
#
# The previous implementation uses a global fscache_volume for all erofs
# filesystems. When old user daemon exits, and a new user daemon (with
# a different tag) starts, the fscache_volume will exist there, still
# bound to the cache created by the old user daemon. Later when a new
# erofs filesystem is mounted, it will be bound to the global
# fscache_volume. However since the fscache_volume is bound to a DEAD
# cache (since the old user daemon has exited), fscache_begin_operation()
# will fail with -ENOBUFS.
#
# fscache_begin_operation
#	fscache_begin_cookie_access
#		fscache_cache_is_live(cookie->volume->cache)
#
# The new implementation fixes this by creating one fscache_volume for
# each erofs filesystem.


fscachedir="/root"
_bootstrap="test.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

_volume="erofs,$_bootstrap"
volume="I$_volume"

bootstrap_fan=$(../getfan $_volume $_bootstrap)
bootstrap_path="$fscachedir/cache/$volume/@$bootstrap_fan/D$_bootstrap"


rm -f $bootstrap_path
cp img/noinline/test.img ../
cp img/noinline/test.img .

# Create cache tagged with default "CacheFiles"
bash -c "./test03-daemon $fscachedir > /dev/null &"
sleep 2

mount -t erofs none -o fsid=test.img /mnt/
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill test03-daemon
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "read failed"
	umount /mnt
	pkill test03-daemon
	exit
fi

if [ "$content" != "test" ]; then
	echo "data corruption ($content)"
	umount /mnt
	pkill test03-daemon
	exit
fi

umount /mnt

pkill test03-daemon
sleep 1

# Create cache tagged with default "test"
cd ../
./cachefilesd2 $fscachedir > /dev/null  &
sleep 2
cd test

mount -t erofs none -o fsid=test.img /mnt/
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[pass]"


#cleanup
pkill cachefilesd2
