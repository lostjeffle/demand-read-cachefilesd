all: cachefilesd
	gcc ../libcachefilesd.c test02-daemon.c -o test02-daemon

cachefilesd:
	make -C ../

clean:
	rm -f *.img
	rm -f test*-daemon
