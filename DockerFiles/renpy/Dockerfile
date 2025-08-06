FROM archlinux:latest
RUN pacman -Sy base reflector sudo --noconfirm
RUN reflector --country "India" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
RUN  pacman -Sy debugedit  base-devel fakeroot python3 git libglvnd firefox tk vulkan-driver libva-mesa-driver mesa-vdpau jack2-dbus freeglut webp-pixbuf-loader intel-media-driver libva-intel-driver libva-mesa-driver xdg-utils  alsa-plugins pulseaudio-alsa nvidia  pulseaudio pipewire pipewire-audio pipewire-jack-client pipewire-v4l2 pipewire-alsa mesa xorg-server xorg-xinit --noconfirm
# makepkg user and workdir
ARG user=makepkg
RUN useradd --system --create-home $user \
  && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
USER $user
WORKDIR /home/$user

# Install yay
RUN git clone https://aur.archlinux.org/yay.git \
  && cd yay \
  && makepkg -sri --needed --noconfirm \
  && cd \
  # Clean up
  && rm -rf .cache yay

USER root
# Generating a universally unique ID for the Container
COPY ./entrypoint.sh /

RUN groupadd -r renpy && useradd -m -r -g renpy renpy && \
    usermod -u 1000 renpy && \
    usermod -aG audio renpy && \
    echo 'renpy ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN usermod -aG wheel renpy
RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN chown renpy:renpy -R /home/renpy/ /entrypoint.sh
RUN yes dev|passwd root
RUN  dbus-uuidgen > /etc/machine-id
USER renpy
WORKDIR /home/renpy
RUN chmod +x /entrypoint.sh
CMD  pulseaudio -D && /bin/bash
