```diff
 pacman -S xorg-xhost
 xhost +local:*
 
 - Disallow X server connection 
 xhost -local:*
 ```
 Dockerfile
 ```
FROM archlinux:latest
RUN  pacman -Sy firefox --noconfirm
# Generating a universally unique ID for the Container
RUN  dbus-uuidgen > /etc/machine-id
CMD  /usr/bin/firefox
 ```
run it
```
docker build -t guifox .
# need to mount xsocket -v /tmp/.X11-unix/:/tmp/.X11-unix/ or simply mount /tmp/ 

docker run -e DISPLAY=$DISPLAY  -v /tmp/:/tmp/ --name firefox guifox
```
 
