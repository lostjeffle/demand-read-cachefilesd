#!/bin/bash
#
# Test user daemon closing anon_fd prematurely.
# If user daemon closes anon_fd prematurely, the following read -EIO.

echo "ignore since failover"
exit

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

bash -c "./test06-daemon $fscachedir > /dev/null  &"
sleep 2

log=$(mount -t erofs none -o fsid=test.img /mnt/ 2>&1)
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umont /mnt
	pkill test06-daemon
	exit
fi

echo "$log" | grep -q "can't read superblock"
if [ $? -ne 0 ]; then
	echo "mount failed not as expected ($log)"
	pkill test06-daemon
	exit
fi

echo "[pass]"

#cleanup
pkill test06-daemon
