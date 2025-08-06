#!/bin/bash
#xhost +local:*
xhost +si:localuser:$(whoami)
docker run --device /dev/dri/ -it   \
	--security-opt no-new-privileges \
	-v /run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse:ro \
	-v /tmp/.X11-unix:/tmp/.X11-unix:ro \
	--read-only \
	--tmpfs /tmp \
	-e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native \
	--device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm \
	--device /dev/snd \
	-v /home/$(whoami)/.renpy:/home/renpy/.renpy:rw \
	-v /home/$(whoami)/.config/unity3d:/home/renpy/.config/unity3d:rw \
	-e DRI_PRIME=1 \
	-e __NV_PRIME_RENDER_OFFLOAD=1 \
	-e __GLX_VENDOR_LIBRARY_NAME=nvidia \
	--net=none \
	--cap-drop=ALL \
	-e __VK_LAYER_NV_optimus=NVIDIA_only \
	--runtime=nvidia --gpus all \
	-e  DISPLAY=$DISPLAY  -v `pwd`:"/game/":rw  -w /game awcator/renpygamelauncher:1.0 bash -c "pulseaudio -D;$1"
#SDL_AUDIODRIVER
#PULSE_SERVER=unix:/run/user/0/pulse/native
#--device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm \
#--gpus all \
#--device /dev/dri/card1:/dev/dri/card1 \
