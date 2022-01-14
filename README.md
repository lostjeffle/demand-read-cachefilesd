[Quick Test]
============
You could run run.sh to start a quick test. This test will build an
erofs from @inputdir directory, start the cachefilesd2 daemon, and
mount the built erofs at @mntdir.

```
./run.sh
Example: ./run.sh inputdir mntdir fscachedir
  inputdir: an erofs image will be built from this directory
  mntdir: the built erofs will be mounted on this path
  fscachedir: root directory of cachefiles
```


[Build]
=======
```
gcc setxattr.c -o setxattr
gcc getfan.c hash.c -o getfan
gcc cachefilesd2.c hash.c -o cachefilesd2
```


[Test]
======
You could also setup the test step by step.

1. create erofs image from directory <dir>
(https://git.kernel.org/pub/scm/linux/kernel/git/xiang/erofs-utils.git)

```
(This will create one bootstrap "Dtest.img" and one data blob "Dblob1.img")
mkfs.erofs --chunksize=1048576 --blobdev=Dblob1.img -Eforce-chunk-indexes Dtest.img <dir>
```

```
ls *.img -l
 -rw-r--r-- 1 root root 8040448 Jan 11 16:40 Dblob1.img
 ---------- 1 root root   28672 Jan 11 16:40 Dtest.img
```


2. create sparse blob files (with corresponding file size) under fscache root
directory (e.g. "/root")

```
truncate -s 28672 cache/Ierofs/@9c/Dtest.img
truncate -s 8040448 cache/Ierofs/@b5/Dblob1.img
```

You could get the path where these image files shall be put by getfan, e.g.
```
Using example: getfan <img_name>

$./getfan Dtest.img
You should put this image at <cachefiles_root>/cache/Ierofs/@9c/Dtest.img

$./getfan Dblob1.img
You should put this image at <cachefiles_root>/cache/Ierofs/@b5/Dblob1.img
```


3. set "CacheFiles.cache" xattr for blob files in advance

```
Using example: setxattr <img_path> <img_size>

./setxattr cache/Ierofs/@9c/Dtest.img 28672
./setxattr cache/Ierofs/@b5/Dblob1.img 8040448
```


4. run user daemon

```
./cachefilesd2
```


5. mount erofs from bootstrap

```
mount -t erofs none -o uuid=test.img -o device=blob1.img /mnt/
```
