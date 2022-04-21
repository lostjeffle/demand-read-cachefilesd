#!/bin/bash
#
# Test if the pending requests could be completed when daemon gets killed.
#
# Each request needs to be replied in current implementation, or the request
# will never be completed and thus the user program triggers this reqeust will
# hang (state D) there forever. When the device fd is closed, e.g. the daemon
# gets killed, all the pending requests will be completed, and the previous
# program will be awaken then.

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

(./test12-daemon $fscachedir 2>&1 > /dev/null &)
sleep 2

# mount will hang since test12-daemon will discard all READ requests
# without replying, and thus call "mount" in background
mount -t erofs none -o fsid=test.img /mnt/ > /dev/null 2>&1 &
mount_pid=$!
sleep 1

# now the mount shall hang there
ps -p $mount_pid > /dev/null
if [ $? -ne 0 ]; then
	echo "The mount shall hang there ..."
	pkill test12-daemon
	exit
fi

# when daemon is killed, all pending requests shall be completed
pkill test12-daemon
sleep 1

ps -p $mount_pid > /dev/null
if [ $? -eq 0 ]; then
	echo "All pending requests shall be completed when daemon is killed ..."
	exit
fi

echo "[pass]"
