#!/bin/bash
#
# Test the behavior when user daemon fails to handle READ request.
#
# If user daemon fails to handle READ request, that is, there's no data
# written into the cache file, whilst a response to the READ request
# has been sent to kernel, the read actually returns -ENODATA.


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

bash -c "./test05-daemon $fscachedir 5 > /dev/null  &"
sleep 2

log=$(mount -t erofs none -o fsid=test.img /mnt/ 2>&1)
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umont /mnt
	pkill test05-daemon
	exit
fi

echo "$log" | grep -q "No data available"
if [ $? -ne 0 ]; then
	echo "mount failed not as expected ($log)"
	pkill test05-daemon
	exit
fi

echo "[pass]"

#cleanup
pkill test05-daemon
