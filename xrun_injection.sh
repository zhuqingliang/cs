#!/bin/bash

int=0
while [ $int -lt 100000 ]
do
	echo 0 > /proc/asound/card0/pcm0p/sub0/xrun_injection 
	echo 0 > /proc/asound/card0/pcm0c/sub0/xrun_injection
	sleep 1
	echo $int
	let int++
done
