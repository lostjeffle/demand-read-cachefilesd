#!/bin/bash
#
# Fuzz Test
#
# Test if system could recover from previous wrong behaved user daemon.


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

cp img/noinline/test.img ../
cp img/noinline/test.img .

for i in {0..7}; do
	# 1. error injection
	rm -f $bootstrap_path
	bash -c "./test05-daemon $fscachedir $i > /dev/null &"
	sleep 1

	mount -t erofs none -o fsid=test.img /mnt/ > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		cat /mnt/file > /dev/null 2>&1
	fi

	umount /mnt > /dev/null 2>&1
	pkill test05-daemon
	sleep 1

	# 2. test cachefilesd2
	rm -f $bootstrap_path
	cd ../
	bash -c "./cachefilesd2 $fscachedir > /dev/null &"
	sleep 1
	cd test/

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
	pkill cachefilesd2
	sleep 1
done

echo "[pass]"

#cleanup
rm -f *.img
rm -f ../*.img
