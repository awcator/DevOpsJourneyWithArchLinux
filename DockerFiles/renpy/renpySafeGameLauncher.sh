#!/bin/bash
#xhost +local:*
xhost +si:localuser:$(whoami)

# --- Defer: reset the display after the game exits -------------------------
# krkr/wine (and some Ren'Py) games lower the screen resolution (e.g. native
# 1920x1200 -> 1280x800) and leave it that way. Reset the primary output back
# to its preferred/native mode on exit, Go-defer style.
restore_display() {
	local out
	out="$(xrandr --query 2>/dev/null | awk '/ connected primary/{print $1; exit}')"
	[ -n "$out" ] && xrandr --output "$out" --auto 2>/dev/null
}
trap restore_display EXIT

# --- Detect game type -----------------------------------------------------
# Kirikiri (krkr) / .xp3 Japanese visual novels run under Wine with a
# Japanese locale and a persistent WINEPREFIX. Everything else is Ren'Py.
if [ -f "krkr.eXe" ] || [ -f "data.xp3" ]; then
	mkdir -p "$HOME/.winekrkr"
	EXTRA_ARGS=(
		-v "$HOME/.winekrkr":/home/renpy/.wine:rw
		-e WINEPREFIX=/home/renpy/.wine
		-e LANG=ja_JP.UTF-8
		-e LC_ALL=ja_JP.UTF-8
		-e WINEDEBUG=-all
		-e "WINEDLLOVERRIDES=mscoree=d;mshtml=d"
		--tmpfs /home/renpy/.cache
	)
	RUN_CMD="pulseaudio -D; exec wine ${1:-krkr.eXe}"
else
	EXTRA_ARGS=(
		-v /home/$(whoami)/.renpy:/home/renpy/.renpy:rw
		-v /home/$(whoami)/.config/unity3d:/home/renpy/.config/unity3d:rw
	)
	RUN_CMD="pulseaudio -D;$1"
fi

docker run --device /dev/dri/ -it   \
	--security-opt no-new-privileges \
	-v /run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse:ro \
	-v /tmp/.X11-unix:/tmp/.X11-unix:ro \
	--read-only \
	--tmpfs /tmp \
	-e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native \
	--device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm \
	--device /dev/snd \
	"${EXTRA_ARGS[@]}" \
	-e DRI_PRIME=1 \
	-e __NV_PRIME_RENDER_OFFLOAD=1 \
	-e __GLX_VENDOR_LIBRARY_NAME=nvidia \
	--net=none \
	--cap-drop=ALL \
	-e __VK_LAYER_NV_optimus=NVIDIA_only \
	--runtime=nvidia \
	-e  DISPLAY=$DISPLAY  -v "$(pwd):/game:rw"  -w /game awcator/renpygamelauncher:1.0 bash -c "$RUN_CMD"
#SDL_AUDIODRIVER
#PULSE_SERVER=unix:/run/user/0/pulse/native
#--device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm \
#--gpus all \
#--device /dev/dri/card1:/dev/dri/card1 \
