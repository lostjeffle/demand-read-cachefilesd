all: cachefilesd
	gcc ../libcachefilesd.c test02-daemon.c -o test02-daemon
	gcc ../libcachefilesd.c test03-daemon.c -o test03-daemon
	gcc ../libcachefilesd.c test04-daemon.c -o test04-daemon
	gcc ../libcachefilesd.c test05-daemon.c -o test05-daemon

cachefilesd:
	make -C ../

clean:
	rm -f *.img
	rm -f test*-daemon
