#!/bin/bash
#
# Test writing to premature anon_fd.
#
# Writing to premature anon_fd (object->file == NULL) shall returns -ENOBUFS.


fscachedir="/root"

make > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "make failed"
	exit
fi


rm -rf "$fscachedir/cache/"
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
