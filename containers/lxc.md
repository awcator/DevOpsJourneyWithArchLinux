# Getting started
read: https://linuxcontainers.org/lxc/getting-started/
```diff
pacman -S lxc
lxc-checkconfig
# pacman -Sy lxc debootstrap 
mkdir ~/.config/lxc
cp /etc/lxc/default.conf ~/.config/lxc/

sudo lxc-create --name=ubuntu-16 --template=download -- --dist ubuntu --release xenial --arch amd64
# or
sudo lxc-create --name=awcatorNodesArch --template=download -- --dist archlinux --release current --arch amd64
# or
sudo lxc-create -t download -n my-container
# roottfs will be downloaded to /var/cache/lxc/download/
sudo lxc-ls

#lxd setup
pacman -Sy lxd
sudo groupadd lxd
# register user to lxd group. where awcator is my host user
sudo gpasswd -a awcator lxd
# verify
getent group lxd
# or
id
# or
groups

#if id dnst reflect group changes. do relogin or use
newgrp lxd

systemctl start lxd
systemctl status lxd
```
# settingup LXD
```
l
```
# Settingup LXC network
Host bridge network read : https://wiki.archlinux.org/title/Network_bridge
```
  $ cat ~/.config/lxc/default.conf 
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:xx:xx:xx

sudo pacman -S bridge-utils
sudo brctl addbr lxcbr0
sudo ip addr add 10.0.0.1/24 dev lxcbr0
sudo ip link set dev lxcbr0 up
#add entry in sudo cat /var/lib/lxc/awcatorNodesArch/config
lxc.net.0.ipv4.address = 10.0.0.2/24  
lxc.net.0.ipv4.gateway = 10.0.0.1

sudo systemctl restart lxc.service
# lxc-net.service creates network
sudo lxc-start -n awcatorNodesArch

# confirm it is running
sudo lxc-ls -f

# we can verify what kind of network container will run in
cat /var/lib/lxc/awcatorNodesArch/config
# where awcatorNodesArch  is the container name
```
# Cleanup
```
sudo lxc-ls
sudo lxc-destroy ubuntu-16
```