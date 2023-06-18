#!/bin/bash
xhost +local:*
docker run --device /dev/dri/ -it -v /run/user/1000/pulse:/tmp/run/user/973/pulse  -e SDL_AUDIODRIVER=pulseaudio -e  DISPLAY=$DISPLAY --net=none -v `pwd`:"/game/" -v /tmp/:/tmp/ -w /game awcator/renpygamelauncher bash -c "pulseaudio -D;$1"
#SDL_AUDIODRIVER
#PULSE_SERVER=unix:/run/user/0/pulse/native
