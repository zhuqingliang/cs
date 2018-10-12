#!/bin/bash

aplay -D hw:0,0 -c 2 -r 48000 -f s16_le Music/48California_Dreaming.wav --period-size=192 --buffer-size=384 -vv -i
