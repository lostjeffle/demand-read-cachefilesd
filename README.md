[Quick Test]
============

1. Start cachefilesd2 daemon
----------------------------

You could run run.sh to start a quick test. This test will run mkfs.erofs
from @inputdir directory, start the cachefilesd2 daemon, and mount the built
erofs at @mntdir.

```
./run.sh
Example: ./run.sh inputdir mntdir fscachedir
  inputdir: an erofs image will be built from this directory
  mntdir: the built erofs will be mounted on this path
  fscachedir: root directory of cachefiles
```

```
./run.sh inputdir mntdir fscachedir
  Ctrl-C to kill cachefilesd2 when test finished...
```


2. Check Mounting
-----------------

By the time run.sh runs, the erofs image created from mkfs.erofs will have
already been mounted on @mntdir. Now you can check the mount instance under
@mntdir.


3. Cleanup
----------

Kill the running run.sh by Ctrl-C. The script will umount and kill cachefilesd2
daemon on exit.
