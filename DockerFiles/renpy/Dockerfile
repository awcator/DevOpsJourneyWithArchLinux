FROM archlinux:latest
RUN  pacman -Sy python3 libglvnd firefox --noconfirm
#install some drivers
RUN pacman -S tk vulkan-driver libva-mesa-driver mesa-vdpau jack2-dbus freeglut webp-pixbuf-loader intel-media-driver libva-intel-driver libva-mesa-driver xdg-utils --noconfirm
RUN pacman -S alsa-plugins pulseaudio-alsa --noconfirm
# Generating a universally unique ID for the Container
COPY ./entrypoint.sh /
RUN pacman -S pulseaudio pipewire pipewire-audio pipewire-jack-client pipewire-v4l2 pipewire-alsa --noconfirm
RUN groupadd -r renpy && useradd -m -r -g renpy renpy
#set userid as 971
RUN usermod -u 1000 renpy
RUN usermod -aG audio renpy
RUN chown renpy:renpy -R /home/renpy/ /entrypoint.sh
RUN yes dev|passwd root
RUN  dbus-uuidgen > /etc/machine-id
USER renpy
RUN chmod +x /entrypoint.sh
CMD  pulseaudio -D && /bin/bash
