#!/bin/bash
#
# Linux compiling test.

fscachedir="/root"
_bootstrap="linux-bootstrap.img"
_datablob="linux-blob1.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

_volume="erofs,$_bootstrap"
volume="I$_volume"

bootstrap_fan=$(../getfan $_volume $_bootstrap)
bootstrap_path="$fscachedir/cache/$volume/@$bootstrap_fan/D$_bootstrap"

datablob_fan=$(../getfan $_volume $_datablob)
datablob_path="$fscachedir/cache/$volume/@$datablob_fan/D$_datablob"

rm -f $bootstrap_path
rm -f $datablob_path

cp img/$_bootstrap .
cp img/$_datablob .

./test08-daemon $fscachedir > /dev/null  &

sleep 2

rm -rf /mnt/upper /mnt/work
mkdir -p /mnt/lower /mnt/upper /mnt/work /mnt/test

mount -t erofs none -o fsid=${_bootstrap},device=${_datablob} /mnt/lower
if [ $? -ne 0 ]; then
	echo "mount erofs failed"
	pkill test08-daemon
	exit
fi

mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/upper,workdir=/mnt/work none /mnt/test
if [ $? -ne 0 ]; then
	echo "mount overlay failed"
	umount /mnt/lower
	pkill test08-daemon
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
	pkill test08-daemon
	exit
fi


echo "pass"

#cleanup
cd ~
umount /mnt/test
umount /mnt/lower
pkill test08-daemon
