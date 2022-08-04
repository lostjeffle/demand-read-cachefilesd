all: cachefilesd
	gcc ../libcachefilesd.c test02-daemon.c -o test02-daemon
	gcc ../libcachefilesd.c test03-daemon.c -o test03-daemon
	gcc ../libcachefilesd.c test04-daemon.c -o test04-daemon
	gcc ../libcachefilesd.c test05-daemon.c -o test05-daemon
	gcc ../libcachefilesd.c test06-daemon.c -o test06-daemon
	gcc ../libcachefilesd.c test08-daemon.c -o test08-daemon
	gcc ../libcachefilesd.c test09-daemon.c -o test09-daemon
	gcc ../libcachefilesd.c test10-daemon.c -o test10-daemon
	gcc ../libcachefilesd.c test11-daemon.c -o test11-daemon
	gcc ../libcachefilesd.c test12-daemon.c -o test12-daemon
	gcc ../libcachefilesd.c test13-daemon.c -o test13-daemon
	gcc ../libcachefilesd.c test18-daemon.c -o test18-daemon

cachefilesd:
	make -C ../

clean:
	rm -f *.img
	rm -f test*-daemon
