#!/bin/bash
#
# Linux compiling test (readahead).

fscachedir="/root"
_bootstrap="linux-bootstrap.img"
_datablob="linux-blob1.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

rm -rf "$fscachedir/cache/"

# prepare erofs images containing the linux kernel source
if [[ ! -e img/$_bootstrap || ! -e img/$_datablob ]]; then
	wget "http://jingbo-sh.oss-cn-shanghai.aliyuncs.com/linux-imgs.tgz?OSSAccessKeyId=LTAI5tARuXnWJ1YPFqsnaRSW&Expires=1965887251&Signature=baRS%2FZWj54pBlUtH7%2F5R1nJ2DTg%3D" -O img/linux-imgs.tgz
	if [ $? -ne 0 ]; then
		echo "linux images doesn't exist and failed to download"
		exit
	fi

	pushd img/ > /dev/null
	tar -xf linux-imgs.tgz
	popd > /dev/null

	if [[ ! -e img/$_bootstrap || ! -e img/$_datablob ]]; then
		echo "linux images doesn't exist"
		exit
	fi
fi

cp img/$_bootstrap .
cp img/$_datablob .

./test09-daemon $fscachedir > ~/daemon.log &

sleep 2

rm -rf /mnt/upper /mnt/work
mkdir -p /mnt/lower /mnt/upper /mnt/work /mnt/test

mount -t erofs none -o fsid=${_bootstrap},device=${_datablob} /mnt/lower
if [ $? -ne 0 ]; then
	echo "mount erofs failed"
	pkill test09-daemon
	exit
fi

modprobe overlayfs
mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/upper,workdir=/mnt/work none /mnt/test
if [ $? -ne 0 ]; then
	echo "mount overlay failed"
	umount /mnt/lower
	pkill test09-daemon
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
	pkill test09-daemon
	exit
fi


echo "[pass]"

#cleanup
cd ~
umount /mnt/test
umount /mnt/lower
pkill test09-daemon
