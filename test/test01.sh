#!/bin/bash
#
# Test data plane for inline/no-inline/multidev layout.

fscachedir="/root"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

rm -rf "$fscachedir/cache/"

cd ..
./cachefilesd2 $fscachedir > /dev/null  &
cd test
sleep 2


# test noinline data layout
cp img/noinline/test.img ../noinline-test.img

mount -t erofs none -o fsid=noinline-test.img /mnt/
if [ $? -ne 0 ]; then
	echo "[noinline] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "[noinline] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[noinline] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[noinline] pass"


# test inline data layout
cp img/inline/test.img ../inline-test.img

mount -t erofs none -o fsid=inline-test.img /mnt/
if [ $? -ne 0 ]; then
	echo "[inline] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "[inline] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[inline] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[inline] pass"

# test multidev data layout
cp img/multidev/test.img ../multidev-test.img
cp img/multidev/blob1.img ../multidev-blob1.img

mount -t erofs none -o fsid=multidev-test.img,device=multidev-blob1.img /mnt/
if [ $? -ne 0 ]; then
	echo "[multidev] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/stamp-h1)"
if [ $? -ne 0 ]; then
	echo "[multidev] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "timestamp for config.h" ]; then
	echo "[multidev] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[multidev] pass"


#cleanup
pkill cachefilesd2
