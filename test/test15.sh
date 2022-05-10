#!/bin/bash
#
# Test if data blobs can be automatically initiated from device
# table when "-o device" mount option is not specified. In this
# case, the tag maintained inside the device table, which specifies
# the name of the according data blob, can not be empty.

fscachedir="/root"
_bootstrap="device-bootstrap.img"
_datablob="device-blob1.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

_volume="erofs,$_bootstrap"
volume="I$_volume"


# devices are initiated from device table when '-o device='
# mount option is not specified
rm -rf "$fscachedir/cache/$volume"
cp -f img/device/*.img ..

cd ..
(./cachefilesd2 $fscachedir > /dev/null 2>&1 &)
cd test
sleep 1

mount -t erofs none -o fsid=${_bootstrap} /mnt/ 2>&1
if [ $? -ne 0 ]; then
	echo "mount failed"
	pkill cachefilesd2
	exit
fi

cat /mnt/AUTHORS > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "data plane failed"
	pkill cachefilesd2
	exit
fi

umount /mnt
pkill cachefilesd2
sleep 1

# the tag inside device table shall not be empty if devices
# are initiated from device table
rm -rf "$fscachedir/cache/$volume"
cp -f img/device/device-bootstrap-invalid.img ../device-bootstrap.img

cd ..
(./cachefilesd2 $fscachedir > /dev/null 2>&1 &)
cd test
sleep 1

mount -t erofs none -o fsid=${_bootstrap} /mnt/ > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

echo "[pass]"

#cleanup
pkill cachefilesd2
