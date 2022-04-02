all:
	gcc getfan.c hash.c -o getfan
	gcc libcachefilesd.c cachefilesd2.c -o cachefilesd2
