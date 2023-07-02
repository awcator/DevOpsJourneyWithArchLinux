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
# settingup LXD/LXC
```
  $ lxd init
Would you like to use LXD clustering? (yes/no) [default=no]: no
Do you want to configure a new storage pool? (yes/no) [default=yes]: yes
Name of the new storage pool [default=default]: awcator_storage
Name of the storage backend to use (dir, lvm, btrfs) [default=btrfs]: dir
Would you like to connect to a MAAS server? (yes/no) [default=no]: no
Would you like to create a new local network bridge? (yes/no) [default=yes]: yes
What should the new bridge be called? [default=lxdbr0]: lxdbr0
What IPv4 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: auto
What IPv6 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: none
Would you like the LXD server to be available over the network? (yes/no) [default=no]: no
Would you like stale cached images to be updated automatically? (yes/no) [default=yes]: yes
Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: no

  $ lxc version
Client version: 5.15
Server version: 5.15

  $ lxc storage list
+-----------------+--------+--------------------------------------------+-------------+---------+---------+
|      NAME       | DRIVER |                   SOURCE                   | DESCRIPTION | USED BY |  STATE  |
+-----------------+--------+--------------------------------------------+-------------+---------+---------+
| awcator_storage | dir    | /var/lib/lxd/storage-pools/awcator_storage |             | 1       | CREATED |
+-----------------+--------+--------------------------------------------+-------------+---------+---------+

lxc remote list
# list images form localmachine
lxc image list
# list images form server
lxc image list images:
lxc image list images:arch
lxc launch images:archlinux
lxc list

# if lxc failed to launch due to UID mappings:
$ cat /etc/subgid 
root:200000:65536
awcator:100000:65536

$ cat /etc/subuid 
root:200000:65536
awcator:100000:65536

lxc config set casual-lioness volatile.idmap.next '[{"Isuid":true,"Isgid":false,"Hostid":200000,"Nsid":0,"Maprange":65535},{"Isuid":false,"Isgid":true,"Hostid":200000,"Nsid":0,"Maprange":65535}]'
lxc config set casual-lioness volatile.idmap.current '[{"Isuid":true,"Isgid":false,"Hostid":200000,"Nsid":0,"Maprange":65535},{"Isuid":false,"Isgid":true,"Hostid":200000,"Nsid":0,"Maprange":65535}]'
# where casual-lioness is the container name

# add in cat /etc/lxc/default.conf 
lxc.idmap = u 0 200000 65535
lxc.idmap = g 0 200000 65535
```
[read here why those exact values in subuids](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/containers/userspace.md)
```
sudo chmod 5755 /usr/bin/newuidmap
sudo chmod 5755 /usr/bin/newgidmap
lxc start casual-lioness


#manual Launch
/usr/bin/lxd forkstart casual-lioness /var/lib/lxd/containers /var/log/lxd/casual-lioness/lxc.conf
# view logs
lxc info --show-log local:casual-lioness
```
# Settingup LXC network (The hardway)
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
