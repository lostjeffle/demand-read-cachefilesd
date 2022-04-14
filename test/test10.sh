#!/bin/bash
#
# Test llseek.


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
cp img/noinline/test.img .

./test10-daemon $fscachedir > daemon.log &
sleep 2

mount -t erofs none -o fsid=test.img /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "mount faild"
	pkill test10-daemon
	exit
fi

grep -q "llseek: SEEK_DATA 0, SEEK_HOLE 4096" daemon.log
if [ $? -ne 0 ]; then
	echo "llseek failed"
	umount /mnt
	pkill test10-daemon
	exit
fi

echo "[pass]"

#cleanup
umount /mnt
pkill test10-daemon
