#!/bin/bash
#
# Test if multiple erofs filesystem instances can be mounted at the same time.

fscachedir="/root"
_bootstrap1="test1.img"
_bootstrap2="test2.img"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi

_volume1="erofs,$_bootstrap1"
volume1="I$_volume1"
bootstrap_fan1=$(../getfan $_volume1 $_bootstrap1)
bootstrap_path1="$fscachedir/cache/$volume1/@$bootstrap_fan1/D$_bootstrap1"

_volume2="erofs,$_bootstrap2"
volume2="I$_volume2"
bootstrap_fan2=$(../getfan $_volume2 $_bootstrap2)
bootstrap_path2="$fscachedir/cache/$volume2/@$bootstrap_fan2/D$_bootstrap2"

rm -f $bootstrap_path1
rm -f $bootstrap_path2
cp -f img/noinline/test.img ./$_bootstrap1
cp -f img/noinline/test.img ./$_bootstrap2

../cachefilesd2 $fscachedir > /dev/null 2>&1 &
sleep 1

mkdir -p /mnt1 /mnt2

# mount two erofs instances
mount -t erofs none -o fsid=$_bootstrap1 /mnt1 2>&1
if [ $? -ne 0 ]; then
	echo "[$_bootstrap1] mount failed"
	pkill cachefilesd2
	exit
fi

mount -t erofs none -o fsid=$_bootstrap2 /mnt2 2>&1
if [ $? -ne 0 ]; then
	echo "[$_bootstrap2] mount failed"
	umount /mnt1
	pkill cachefilesd2
	exit
fi

# data corruption check of two erofs instances
content="$(cat /mnt1/file)"
if [ $? -ne 0 ]; then
	echo "[$_bootstrap1] read failed"
	umount /mnt1
	umount /mnt2
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[$_bootstrap1] data corruption ($content)"
	umount /mnt1
	umount /mnt2
	pkill cachefilesd2
	exit
fi


content="$(cat /mnt2/file)"
if [ $? -ne 0 ]; then
	echo "[$_bootstrap2] read failed"
	umount /mnt1
	umount /mnt2
	pkill cachefilesd2
	exit
fi

if [ "$content" != "test" ]; then
	echo "[$_bootstrap2] data corruption ($content)"
	umount /mnt1
	umount /mnt2
	pkill cachefilesd2
	exit
fi


echo "[pass]"

# cleanup
umount /mnt1
umount /mnt2
pkill cachefilesd2
