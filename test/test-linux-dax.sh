#!/bin/bash
#
# Linux compiling test.

dd if=/root/demand-read-cachefilesd/test/img/linux.img of=/dev/pmem0 oflag=direct

rm -rf /mnt/upper /mnt/work
mkdir -p /mnt/lower /mnt/upper /mnt/work /mnt/test

mount -t erofs -o dax /dev/pmem0 /mnt/lower
if [ $? -ne 0 ]; then
	echo "mount erofs failed"
	exit
fi

modprobe overlayfs
mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/upper,workdir=/mnt/work none /mnt/test
if [ $? -ne 0 ]; then
	echo "mount overlay failed"
	umount /mnt/lower
	exit
fi

source /opt/rh/devtoolset-9/enable
cd /mnt/test
cp -f arch/x86/configs/x86_64_defconfig .config
make olddefconfig > /dev/null
make -j32 -s > /dev/null

if [ $? -ne 0 ]; then
	echo "compile failed"
	cd ~
	umount /mnt/test
	umount /mnt/lower
	exit
fi


echo "[pass]"

#cleanup
cd ~
umount /mnt/test
umount /mnt/lower
