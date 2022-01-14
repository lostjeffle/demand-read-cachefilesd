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

gcc setxattr.c -o setxattr
gcc getfan.c hash.c -o getfan
gcc cachefilesd2.c hash.c -o cachefilesd2

if [ ! -e setxattr -o ! -e getfan -o ! -e cachefilesd2 ]; then
	echo "gcc failed"
	exit
fi

# create erofs image, chunk-index layout, chunk size 1M
mkfs.erofs --chunksize=1048576 --blobdev=$datablob -Eforce-chunk-indexes $bootstrap $inputdir

if [ ! -e $bootstrap -o ! -e $datablob ]; then
	echo "mkfs.erofs failed"
	exit
fi

bootstrap_size=$(ls -l $bootstrap | awk '{print $5}')
datablob_size=$(ls -l $datablob | awk '{print $5}')

bootstrap_path=$(./getfan $bootstrap | awk '{print $NF}')
bootstrap_path="$fscachedir/$bootstrap_path"

datablob_path=$(./getfan $datablob | awk '{print $NF}')
datablob_path="$fscachedir/$datablob_path"

rm -f $bootstrap_path
rm -f $datablob_path

truncate -s $bootstrap_size $bootstrap_path
truncate -s $datablob_size $datablob_path

./setxattr $bootstrap_path $bootstrap_size
./setxattr $datablob_path $datablob_size

./cachefilesd2 $fscachedir &
sleep 2
mount -t erofs none -o uuid=${_bootstrap} -o device=${_datablob} ${mntdir}
