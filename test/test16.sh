#!/bin/bash
#
# Test if remounting with "-o fsid" or "-o domain_id" is problematic.
# This is fixed by commit 39bfcb8138f6 ("erofs: fix use-after-free of fsid
# and domain_id string").

fscachedir="/root"
_bootstrap="test.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

rm -rf "$fscachedir/cache/"
cp -f img/noinline/${_bootstrap} ..

cd ..
(./cachefilesd2 $fscachedir > /dev/null 2>&1 &)
cd test
sleep 1


# round 1: mount with initial "fsid"
mount -t erofs none -o fsid=${_bootstrap} /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "mount: failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "mount: read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "mount: data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

mount_option_1="$(mount | grep erofs)"


# round 2: remount with new "fsid"
mount -t erofs none -o remount,fsid="fake.img" /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "remount: failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "remount: read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "remount: data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

mount_option_2="$(mount | grep erofs)"

if [ "$mount_option_1" != "$mount_option_2" ]; then
	echo "fsid shall not be changed by remount"
	echo "mount_option_1: $mount_option_1"
	echo "mount_option_2: $mount_option_2"
	umount /mnt
	pkill cachefilesd2
	exit
fi

echo "[pass]"

#cleanup
umount /mnt
pkill cachefilesd2
