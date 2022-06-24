#!/bin/bash
#
# Test if 'inuse' and 'cull' cmds work as expected.

fscachedir="/root"
_bootstrap="test.img"
bootstrap_path="/root/cache/@24/I05erofs/@84/I0eerofs,test.img/@33/D08test.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

rm -rf "$fscachedir/cache/"
cp -f img/noinline/test.img .
cp -f img/noinline/test.img ..

(../cachefilesd2 $fscachedir > /dev/null 2>&1 &)
sleep 1

mount -t erofs none -o fsid=test.img /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill cachefilesd2
	exit
fi

umount /mnt
pkill cachefilesd2

# make cache file ready under root cache directory
if [ ! -f $bootstrap_path ]; then
	echo "can't find $bootstrap_path"
	exit
fi


# wait for cachefilesd2 exiting
sleep 1

(./test13-daemon $fscachedir "$fscachedir/cache/@24/I05erofs/@84/I0eerofs,test.img/@33/" "D08test.img"  > daemon.log &)
sleep 1

mount -t erofs none -o fsid=test.img /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill test13-daemon
	exit
fi

# trigger a READ request
cat /mnt/file > /dev/null 2>&1

# wait for daemon flushing printing to stdout
sleep 1

if [ ! -f $bootstrap_path ]; then
	echo "$bootstrap_path shall exist"
	umount /mnt
	pkill test13-daemon
	exit
fi

grep -q "is inuse, 16 (Device or resource busy)" daemon.log
if [ $? -ne 0 ]; then
	echo "behaviour of 'inuse' cmd is not expected (state shall be busy)"
	umount /mnt
	pkill test13-daemon
	exit
fi


umount /mnt
pkill test13-daemon

# wait for daemon flushing printing to stdout
sleep 1

# the daemon will run "cull" cmd to delete the image file when CLOSE
# request is received
if [ -f $bootstrap_path ]; then
	echo "$bootstrap_path is not culled"
	exit
fi

grep -q "is not inuse" daemon.log
if [ $? -ne 0 ]; then
	echo "behaviour of 'inuse' cmd is not expected (state shall be free)"
	exit
fi

grep -q "is culled" daemon.log
if [ $? -ne 0 ]; then
	echo "cull failed"
	exit
fi

echo "[pass]"
