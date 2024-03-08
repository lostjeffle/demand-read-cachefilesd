#!/bin/bash
#
# Failover Test
#
# Test if user daemon could recover in-flight requests.

# skip the test since failover has not been merged to upstream yet
#echo "[skip]"
#exit

function kill_child() {
	for i in {1..50}
	do
		pkill cache-child
		sleep 2
	done
}

fscachedir="/root"
_bootstrap="test.img"
_datablob="blob1.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit 1
fi

cp img/failover/test.img .
cp img/failover/blob1.img .
cp img/failover/test.img ..
cp img/failover/blob1.img ..

_volume="erofs,$_bootstrap"
volume="I$_volume"

bootstrap_fan=$(../getfan $_volume $_bootstrap)
bootstrap_path="$fscachedir/cache/$volume/@$bootstrap_fan/D$_bootstrap"
datablob_fan=$(../getfan $_volume $_datablob)
datablob_path="$fscachedir/cache/$volume/@$datablob_fan/D$_datablob"

rm -rf "$fscachedir/cache"

# 1. get origin md5sum by cachefilesd2
cd ../
bash -c "./cachefilesd2 $fscachedir > /dev/null &"
sleep 2
cd test/

mount -t erofs none -o fsid=test.img -o device=blob1.img /mnt/
if [ $? -ne 0 ]; then
	echo "cachefilesd mount failed"
	pkill cachefilesd2
	exit 1
fi

md5sum /mnt/file1G > md5.log
if [ $? -ne 0 ]; then
	echo "read failed"
	umount /mnt
	pkill cachefilesd2
	sleep 1
fi

umount /mnt
pkill cachefilesd2

# 2. check md5sum and make child process crash
sleep 2
rm -rf "$fscachedir/cache"
(./test18-daemon $fscachedir > daemon.log &)
sleep 2

mount -t erofs none -o fsid=test.img -o device=blob1.img /mnt/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "test18-daemon mount failed"
	pkill test18-daemon
	exit 1
fi

kill_child &

md5sum -c --status md5.log
if [ $? -ne 0 ]; then
	echo "mdusum check failed"
	pkill test18-daemon
	pkill cache-child
	umount /mnt > /dev/null 2>&1
	exit 1
fi

umount /mnt > /dev/null 2>&1
sleep 1
echo "[pass]"

#cleanup
killall test18-daemon
pkill cache-child
sleep 1
rm -f *.img
rm -f md5.log
rm -f ../*.img
