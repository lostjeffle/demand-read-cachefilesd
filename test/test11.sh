#!/bin/bash
#
# Test the time sequence of closing device fd before closing anonymous fds.
# The previous implementation once caused the daemon hang (D state) when the
# daemon is going to exit. This is because the kernel implementation will pin
# the corresponding cachefiles object for each anonymous fd. The cachefiles
# object is unpinned when the anonymous fd gets closed. On the other hand, when
# the user daemon exits and the device fd gets closed, it will wait for all
# cahcefiles objects gets withdrawn. Then if there's any anonymous fd getting
# closed after the fd of the device node, the user daemon will hang forever,
# waiting for all objects getting withdrawn.
#
# This is fixed by the kernel commit "cachefiles: unbind cachefiles gracefully
# in on-demand mode".

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
cp -f img/noinline/test.img .
dmesg --clear

(./test11-daemon $fscachedir > daemon.log &)
sleep 2

mount -t erofs none -o fsid=test.img /mnt/ > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umount /mnt/
	pkill test11-daemon
	exit
fi

# wait for test11-daemon flushing printing to stdout
sleep 1

grep -q "done: close cache" daemon.log
if [ $? -ne 0 ]; then
	echo "The daemon shall not hang..."
	pkill test11-daemon
	exit
fi

grep -q "expected: send cread failed" daemon.log
if [ $? -ne 0 ]; then
	echo "ioctl on the anonymous fd shall not succeed when cache is already dead..."
	pkill test11-daemon
	exit
fi

grep -q "done: close anon_fd" daemon.log
if [ $? -ne 0 ]; then
	echo "it seems that the daemon fails to close the anonymous fd ..."
	pkill test11-daemon
	exit
fi

dmesg | grep -q "Withdrawing cache"
if [ $? -ne 0 ]; then
	echo "cache withdrawing is not trigerred ..."
	pkill test11-daemon
	exit
fi

echo "[pass]"

#cleanup
pkill test11-daemon
