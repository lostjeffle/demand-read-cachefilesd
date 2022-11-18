#!/bin/bash
#
# stress test.

fscachedir="/root"

rm -rf "$fscachedir/cache/"

cd ..
./cachefilesd2 $fscachedir > /dev/null  &
cd test

sleep 2

cp img/stress/stress.img ../

mount -t erofs none -o fsid=stress.img /mnt/
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill cachefilesd2
	exit
fi


rm -rf /tmp/stress
mkdir -p /tmp/stress
tar -xf img/stress/erofs-utils.tar -C /tmp/stress

#stress test
./stress -p $(nproc) /mnt /tmp/stress

# cleanup
rm -rf /tmp/stress
umount /mnt
pkill cachefilesd2
