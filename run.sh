#!/bin/bash

if [ $# -ne 3 ]; then
	echo "Example: ./run.sh inputdir mntdir fscachedir"
	echo "  inputdir: an erofs image will be built from this directory"
	echo "  mntdir: the built erofs will be mounted on this path"
	echo "  fscachedir: root directory of cachefiles"
	exit
fi

inputdir=$1
mntdir=$2
fscachedir=$3

_bootstrap="test.img"
_datablob="blob1.img"

bootstrap="D${_bootstrap}"
datablob="D${_datablob}"

gcc getfan.c hash.c -o getfan
gcc libcachefilesd.c cachefilesd2.c -o cachefilesd2

if [ ! -e getfan -o ! -e cachefilesd2 ]; then
	echo "gcc failed"
	exit
fi

mkfs.erofs 2>&1 | grep -q 'command not found'
if [ $? -eq 0 ]; then
	echo "erofs-utils need to be installed."
	echo "https://git.kernel.org/pub/scm/linux/kernel/git/xiang/erofs-utils.git -b master"
	exit
fi

# create erofs image, chunk-index layout, chunk size 1M
mkfs.erofs --chunksize=1048576 --blobdev=$_datablob -Eforce-chunk-indexes $_bootstrap $inputdir

if [ ! -e $_bootstrap -o ! -e $_datablob ]; then
	echo "mkfs.erofs failed"
	exit
fi

_volume="erofs,$_bootstrap"
volume="I$_volume"

bootstrap_fan=$(./getfan $_volume $_bootstrap)
bootstrap_path="$fscachedir/cache/$volume/@$bootstrap_fan/D$_bootstrap"

datablob_fan=$(./getfan $_volume $_datablob)
datablob_path="$fscachedir/cache/$volume/@$datablob_fan/D$_datablob"

rm -f $bootstrap_path
rm -f $datablob_path

./cachefilesd2 $fscachedir &

sleep 2
mount -t erofs none -o fsid=${_bootstrap} -o device=${_datablob} ${mntdir}

trap "umount ${mntdir};pkill cachefilesd2; exit" INT

echo "Ctrl-C to kill cachefilesd2 when test finished..."
read tmp
