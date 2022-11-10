#!/bin/bash
#
# stress test.

mount -t erofs /dev/vdd /mnt/
if [ $? -ne 0 ]; then
	echo "mount erofs failed"
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
