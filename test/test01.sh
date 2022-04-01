#!/bin/bash
#
# Test data plane for inline/no-inline/multidev layout.

fscachedir="/root"
_bootstrap="test.img"
_datablob="blob1.img"

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

cd ..
./cachefilesd2 $fscachedir > /dev/null  &
cd test

sleep 2


# test noinline data layout
cp -a --preserve=xattr img/noinline/test.img $bootstrap_path
cp img/noinline/test.img ../

mount -t erofs none -o fsid=test.img /mnt/
if [ $? -ne 0 ]; then
	echo "[noinline] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "[noinline] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[noinline] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[noinline] pass"


# test inline data layout
cp -a --preserve=xattr img/inline/test.img $bootstrap_path
cp img/inline/test.img ../

mount -t erofs none -o fsid=test.img /mnt/
if [ $? -ne 0 ]; then
	echo "[inline] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/file)"
if [ $? -ne 0 ]; then
	echo "[inline] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[inline] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[inline] pass"

# test multidev data layout
rm -f $bootstrap_path
rm -f $datablob_path
cp -a --preserve=xattr img/multidev/test.img $bootstrap_path
cp -a --preserve=xattr img/multidev/blob1.img $datablob_path
cp -a --preserve=xattr /root/img/multidev/Dtest.img $bootstrap_path
cp -a --preserve=xattr /root/img/multidev/Dblob1.img $datablob_path
cp img/multidev/test.img ../
cp img/multidev/blob1.img ../

mount -t erofs none -o fsid=test.img,device=blob1.img /mnt/
if [ $? -ne 0 ]; then
	echo "[multidev] mount failed"
	pkill cachefilesd2
	exit
fi

content="$(cat /mnt/stamp-h1)"
if [ $? -ne 0 ]; then
	echo "[multidev] read failed"
	umount /mnt
	pkill cachefilesd2
	exit
fi

if [ "$content" != "timestamp for config.h" ]; then
	echo "[multidev] data corruption ($content)"
	umount /mnt
	pkill cachefilesd2
	exit
fi

umount /mnt
echo "[multidev] pass"


#cleanup
pkill cachefilesd2
