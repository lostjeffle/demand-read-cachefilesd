#!/bin/bash
#
# Test writing to premature anon_fd.
#
# Writing to premature anon_fd (object->file == NULL) shall returns -ENOBUFS.


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


# make cache file ready under root cache directory
rm -f $bootstrap_path
cp -a --preserve=xattr img/noinline/test.img $bootstrap_path
cp img/noinline/test.img ../
cp img/noinline/test.img .

bash -c "./test04-daemon $fscachedir > /dev/null &"
sleep 2

mount -t erofs none -o fsid=test.img /mnt/ > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "mount shall not succeed"
	umount /mnt
	pkill test04-daemon
	exit
fi

# since there's no crash
echo "[pass]"

#cleanup
pkill test04-daemon
rm -f *.img
rm -f ../*.img
