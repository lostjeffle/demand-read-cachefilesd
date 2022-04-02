#!/bin/bash
#
# Test error path handling when OPEN request fails.
# During the looking up phase, if cache file is already under root cache
# directory, Cachefiles will mark inode of cache file IN_USE, and send
# an OPEN request to user daemon. If user daemon fails processing this
# OPEN request and returns error, Cachefiles shall unmark the inode
# IN_USE in the error path. In the old kernel, the error path is missing
# and thus the inode is leaked in IN_USE state. In this case, even when
# user daemon processes OPEN request as expected next time, the mount
# will still fail with "No buffer space available", since the inode of
# cache file is still in IN_USE state.
#
# Kernel commit "cachefiles: unmark inode in use in error path" shall
# fix this.


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


# make cache file ready under root cache directory
rm -f $bootstrap_path
cp -a --preserve=xattr img/noinline/test.img $bootstrap_path
cp img/noinline/test.img ../

bash -c "./test02-daemon $fscachedir > /dev/null  &"
sleep 2

log=$(mount -t erofs none -o fsid=test.img /mnt/ 2>&1)
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umont /mnt
	pkill test02-daemon
	exit
fi

echo "$log" | grep -q "No buffer space available"
if [ $? -ne 0 ]; then
	echo "mount failed not as expected ($log)"
	pkill test02-daemon
	exit
fi

pkill test02-daemon
sleep 1

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
