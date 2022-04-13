#!/bin/bash

for cmd in $(ls test*.sh); do
	echo
	echo $cmd
	sleep 1
	bash $cmd
done
