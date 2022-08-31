#!/bin/bash
#
# Test shared domain feature.

fscachedir="/root"
_bootstrap="test.img"
_datablob="blob1.img"

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

# test multidev data layout
cp img/multidev/test.img ../
cp img/multidev/blob1.img ../

mount -t erofs none -o fsid=test.img,device=blob1.img,domain_id=domain0 /mnt/
if [ $? -ne 0 ]; then
	echo "[shared domain] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/stamp-h1)"
if [ $? -ne 0 ]; then
	echo "[shared domain] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "timestamp for config.h" ]; then
	echo "[shared domain] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

mkdir -p mnt2
cp ../test.img ../test2.img

mount -t erofs none -o fsid=test2.img,device=blob1.img,domain_id=domain0 mnt2

content="$(cat mnt2/stamp-h1)"
if [ $? -ne 0 ]; then
	echo "[shared domain] read failed"
	umount /mnt
	umount mnt2
	pkill cachefilesd2
	exit
fi

if [ "$content" != "timestamp for config.h" ]; then
	echo "[shared domain] data corruption ($content)"
	umount /mnt
	umount mnt2
	pkill cachefilesd2
	exit
fi

#cleanup
umount /mnt
umount mnt2
pkill cachefilesd2
rmdir mnt2

num=$(tree "$fscachedir/cache/" | grep blob1.img | wc -l)
if [ $num -ne 1 ]; then
	echo "blob1.img is not shared in the same share_domain (num $num)"
	exit
fi

echo "[pass]"

