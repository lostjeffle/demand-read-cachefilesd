all: cachefilesd
	gcc ../libcachefilesd.c test02-daemon.c -o test02-daemon
	gcc ../libcachefilesd.c test03-daemon.c -o test03-daemon

cachefilesd:
	make -C ../

clean:
	rm -f *.img
	rm -f test*-daemon
